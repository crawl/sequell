#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(setsid); # For daemonization.
use Fcntl qw/:flock SEEK_END/;

use Henzell::Config qw/%CONFIG %CMD %USER_CMD %PUBLIC_CMD/;
use Henzell::Crawl;
use Henzell::Utils;
use Henzell::IRC;
use Henzell::IRCAuth;
use Henzell::SeenService;
use Henzell::TellService;
use Henzell::CommandService;
use Henzell::LogFetchService;
use Henzell::LogParse;
use Henzell::LogReader;
use Getopt::Long;
use Cwd;

END {
  kill TERM => -$$;
}

my $daemon = 1;
my $irc = 1;
my $config_file = 'rc/henzell.rc';
GetOptions("daemon!" => \$daemon,
           "irc!" => \$irc,
           "rc=s" => \$config_file) or die "Invalid options\n";

$ENV{LC_ALL} = 'en_US.UTF-8';
$ENV{RUBYOPT} = "-rubygems -I" . File::Spec->catfile(getcwd(), 'src');

my $SERVER = 'cao';     # Local server.
my $ALT_SERVER = 'cdo'; # Our 'alternative' server.

my @stonefiles;
my @logfiles;

local $SIG{PIPE} = 'IGNORE';
local $SIG{CHLD} = 'IGNORE';
local $| = 1;

load_config($config_file);

# The other bots on the channel that might announce milestones and logfiles.
# When Henzell sees such an announcement, it will fetch logfiles explicitly
# within $sibling_fetch_delay seconds.
my @sibling_bots     = Henzell::Config::array('sibling_bots');

my $nickname       = $CONFIG{bot_nick};
my $ircname        = "$nickname the Crawl Bot";
my $ircserver      = $CONFIG{irc_server};
my $port           = $CONFIG{irc_port} || 6667;

my @CHANNELS         = Henzell::Config::array('channels');

binmode STDOUT, ':utf8';

Henzell::Utils::lock(verbose => 1,
                     lock_name => $ENV{HENZELL_LOCK} || $CONFIG{lock_name});

if ($CONFIG{startup_services}) {
  Henzell::Utils::spawn_services($CONFIG{startup_services});
}

# Daemonify. http://www.webreference.com/perl/tutorial/9/3.html
Henzell::Utils::daemonify() if $daemon;

my $log_reader = Henzell::LogReader->new(logfiles => \@logfiles,
                                         milestones => \@stonefiles);

if ($CONFIG{sql_store}) {
  # Run catchup twice, since processing a large backlog will produce another
  # backlog in the processing time of the first:
  $log_reader->catchup_logs();
  $log_reader->catchup_logs();
}

my $HENZELL;
my %AUTHENTICATED_USERS;
my %PENDING_AUTH;

if ($irc) {
  print "Connecting to $ircserver as $nickname, channels: @CHANNELS\n";
  $HENZELL = Henzell::IRC->new(nick     => $nickname,
                               server   => $ircserver,
                               port     => $port,
                               name     => $ircname,
                               channels => [ @CHANNELS ],
                               flood    => 1,
                               charset  => "utf-8")
    or die "Unable to create Henzell IRC bot\n";
  $HENZELL->configure_services(
    services => irc_services($HENZELL),
    periodic_actions => periodic_actions());
  $HENZELL->run();
}
exit 0;

sub irc_services {
  my $irc_bot = shift;

  my @services;
  my $reg = sub { push @services, shift() };
  my $feat = sub { Henzell::Config::feat_enabled(shift()) };
  $reg->(Henzell::SeenService->new(irc => $irc_bot)) if $feat->('seen_update');

  if ($log_reader->active()) {
    $reg->(
      Henzell::LogFetchService->new(
        irc => $irc_bot,
        siblings => [Henzell::Config::array('sibling_bots')]));
  }

  $reg->(Henzell::TellService->new(irc => $irc_bot));

  # All bots have the command processor; no announce-only bots.
  $reg->(Henzell::CommandService->new(
    irc => $irc_bot,
    auth => Henzell::IRCAuth->new($irc_bot),
    config => $config_file));

  \@services
}

sub periodic_actions {
  my $sql_store = Henzell::Config::feat_enabled('sql_store');
  my $announce = Henzell::Config::feat_enabled('announce');
  return unless $sql_store || $announce;
  [
    sub {
      $log_reader->tail_logs();
    }
  ]
}

sub nick_rule_match {
  my ($rule, $nick) = @_;
  ($$rule{nick} || '') eq $nick
}

sub rule_pattern_match {
  my ($rule, $verbatim) = @_;
  $verbatim =~ qr/$$rule{pattern}/ && $1
}

sub handle_special_command {
  my ($m, $private, $nick, $verbatim) = @_;
  return if $private;
  my $respond_to = $CONFIG{respond_to};
  return unless $respond_to && ref($respond_to) eq 'ARRAY';
  for my $rule (@{$CONFIG{respond_to}}) {
    next unless ref($rule) eq 'HASH';
    next unless nick_rule_match($rule, $nick);
    next unless $$rule{executor} eq 'command';

    my $body = rule_pattern_match($rule, $verbatim);
    next unless $body;
    $$m{body} = $body;
    $$m{proxied} = 1;
    process_command($m);
    return 1;
  }
  undef
}

sub process_config() {
  @logfiles = @Henzell::Config::LOGS unless @logfiles;
  @stonefiles = @Henzell::Config::MILESTONES unless @stonefiles;
}

sub load_config {
  my $config_file = shift;
  my $loaded = Henzell::Config::read($config_file);
  process_config();
  $loaded
}
