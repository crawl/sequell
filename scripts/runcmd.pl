#! /usr/bin/perl

use strict;
use warnings;

use lib 'lib';
use Henzell::Cmd qw/load_all_commands execute_cmd/;
use Henzell::IRCStub;
use Henzell::IRCAuth;
use Henzell::CommandService;
use Henzell::SeenService;
use Henzell::TellService;
use Henzell::ReactorService;
use Henzell::Bus;
use Carp;
use utf8;

do 'sqllog.pl';
do 'game_parser.pl';

my $DEFAULT_NICK = $ENV{NICK} || 'anon';
my $CHANNEL = $ENV{CHANNEL} || '##crawl';
my $CONFIG = $ENV{RC} || 'rc/sequell.rc';

my $irc_auth = ($ENV{IRC_AUTH} || '') eq 'y';
$ENV{IRC_NICK_AUTHENTICATED} = 'y' unless $irc_auth;
$ENV{HENZELL_SQL_QUERIES} = 'y';
$ENV{RUBYOPT} = '-Isrc';
$ENV{PERL_UNICODE} = 'AS';
$ENV{HENZELL_ROOT} = '.';
$ENV{HENZELL_ALL_COMMANDS} = 'y';

$SIG{INT} = sub { Carp::cluck("^C"); exit(1) };

my $irc = Henzell::IRCStub->new(channel => $CHANNEL);

my $logfetch =
my $bus = Henzell::Bus->new;
my $auth = $irc_auth ? Henzell::IRCAuth->new(irc => $irc) : undef;
my $cmd_service =
  Henzell::CommandService->new(irc => $irc,
                               auth => $auth,
                               config => $CONFIG,
                               bus => $bus);
my @services = (
  Henzell::SeenService->new(irc => $irc),
  Henzell::TellService->new(irc => $irc),
  Henzell::ReactorService->new(irc => $irc,
                               auth => $auth,
                               executor => $cmd_service,
                               bus => $bus),
);
$irc->configure_services(services => \@services);

sub runcmd($) {
  chomp(my $cmd = shift);
  my $nick = $DEFAULT_NICK;
  my $pm;
  unless ($cmd =~ /\S/) {
    return $irc->tick();
  }
  if ($cmd =~ s/^PM: *//) {
    $pm = 'msg';
  }
  if ($cmd =~ /^(\w*): (.*)/) {
    $nick = $1 || $DEFAULT_NICK;
    $cmd = $2;
  }

  $irc->tick();
  $irc->said({ who => $nick, channel => $pm || $CHANNEL, body => $cmd });
  $irc->tick();
}

if (@ARGV > 0) {
  runcmd(join(' ', @ARGV));
  exit 0;
}

print "Sequell command runner\n";
while ( my $cmd = do { print "> "; <STDIN> } ) {
  runcmd($cmd);
}
