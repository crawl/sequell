#! /usr/bin/perl

use strict;
use warnings;

use lib 'lib';
use Henzell::Cmd qw/load_all_commands execute_cmd/;
use Henzell::IRCStub;
use Henzell::CommandService;
use Henzell::SeenService;
use Henzell::TellService;
use Henzell::LearnDBService;
use Henzell::Bus;
use utf8;

do 'sqllog.pl';
do 'game_parser.pl';

my $DEFAULT_NICK = $ENV{NICK} || 'greensnark';
my $CHANNEL = $ENV{CHANNEL} || '##crawl';
my $CONFIG = $ENV{RC} || 'rc/sequell.rc';

$ENV{IRC_NICK_AUTHENTICATED} = 'y';
$ENV{HENZELL_SQL_QUERIES} = 'y';
$ENV{RUBYOPT} = '-rubygems -Isrc';
$ENV{PERL_UNICODE} = 'AS';
$ENV{HENZELL_ROOT} = '.';
$ENV{HENZELL_ALL_COMMANDS} = 'y';

my $irc = Henzell::IRCStub->new(channel => $CHANNEL);

my $bus = Henzell::Bus->new;
my $cmd_service =
  Henzell::CommandService->new(irc => $irc,
                               config => $CONFIG,
                               bus => $bus);
my @services = (
  Henzell::SeenService->new(irc => $irc),
  Henzell::TellService->new(irc => $irc),
  Henzell::LearnDBService->new(irc => $irc,
                               executor => $cmd_service,
                               bus => $bus),
  $cmd_service
);
$irc->configure_services(services => \@services);

sub runcmd($) {
  chomp(my $cmd = shift);
  my $nick = $DEFAULT_NICK;
  my $pm;
  return unless $cmd =~ /\S/;
  if ($cmd =~ /^(\w*): (.*)/) {
    $nick = $1 || $DEFAULT_NICK;
    $pm = 'msg' unless $1;
    $cmd = $2;
  }

  $irc->tick();
  $irc->said({ who => $nick, channel => $pm || $CHANNEL, body => $cmd });
}

if (@ARGV > 0) {
  runcmd(join(' ', @ARGV));
  exit 0;
}

print "Henzell command runner\n";
while ( my $cmd = do { print "> "; <STDIN> } ) {
  runcmd($cmd);
}
