#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(setsid); # For daemonization.
use Fcntl qw/:flock SEEK_END/;

use lib 'lib';
use Henzell::Config qw/%CONFIG %CMD %USER_CMD %PUBLIC_CMD/;
use Henzell::Crawl;
use Henzell::Utils;
use Henzell::IRC;
use Henzell::IRCAuth;
use Henzell::SeenService;
use Henzell::TellService;
use Henzell::CommandService;
use Henzell::ReactorService;
use Henzell::LogFetchService;
use Henzell::Bus;
use Getopt::Long;
use Cwd;

END {
  kill TERM => -$$;
}

open STDOUT, '|-', q{( while read line; do echo "[$(date +'%Y-%m-%d %H:%M:%S')] $line"; done )} or die "Couldn't reopen STDOUT: $!\n";
open STDERR, '>&', \*STDOUT or die "Couldn't reopen STDERR: $!\n";

my $daemon = 1;
my $irc = 1;
my $config_file = Henzell::Config::default_config();
GetOptions("daemon!" => \$daemon,
           "irc!" => \$irc,
           "rc=s" => \$config_file) or die "Invalid options\n";

$ENV{LC_ALL} = 'en_US.UTF-8';
$ENV{HENZELL_ROOT} = getcwd();
$ENV{RUBYOPT} = "-rubygems -I" . File::Spec->catfile(getcwd(), 'src');

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
binmode STDERR, ':utf8';

Henzell::Utils::lock(verbose => 1,
                     lock_name => $ENV{HENZELL_LOCK} || $CONFIG{lock_name});

if ($CONFIG{startup_services}) {
  Henzell::Utils::spawn_services($CONFIG{startup_services});
}

# Daemonify. http://www.webreference.com/perl/tutorial/9/3.html
Henzell::Utils::daemonify() if $daemon;

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
    services => irc_services($HENZELL));
  $HENZELL->run();
}
exit 0;

sub irc_services {
  my $irc_bot = shift;

  my @services;
  my $reg = sub { push @services, shift() };
  my $feat = sub { Henzell::Config::feat_enabled(shift()) };

  my $bus = Henzell::Bus->new;

  $reg->(Henzell::SeenService->new(irc => $irc_bot)) if $feat->('seen_update');

  if ($CONFIG{sql_store}) {
    $reg->(
      Henzell::LogFetchService->new(
        irc => $irc_bot,
        siblings => [Henzell::Config::array('sibling_bots')]));
  }

  $reg->(Henzell::TellService->new(irc => $irc_bot));

  my $auth = Henzell::IRCAuth->new(irc => $irc_bot);
  my $executor = Henzell::CommandService->new(
    irc => $irc_bot,
    auth => $auth,
    config => $config_file,
    bus => $bus);

  $reg->(Henzell::ReactorService->new(irc => $irc_bot,
                                      auth => $auth,
                                      executor => $executor,
                                      bus => $bus));

  \@services
}

sub load_config {
  my $config_file = shift;
  my $loaded = Henzell::Config::read($config_file);
  $loaded
}
