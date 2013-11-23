#! /usr/bin/perl

use strict;
use warnings;

use Henzell::Cmd qw/load_all_commands execute_cmd/;
use Henzell::IRCStub;
use Henzell::CommandService;
use Henzell::SeenService;
use Henzell::TellService;
use utf8;

do 'sqllog.pl';
do 'game_parser.pl';

my $DEFAULT_NICK = $ENV{NICK} || 'greensnark';
my $CHANNEL = $ENV{CHANNEL} || '##crawl';
my $CONFIG = $ENV{RC} || 'rc/henzell.rc';

$ENV{IRC_NICK_AUTHENTICATED} = 'y';
$ENV{HENZELL_SQL_QUERIES} = 'y';
$ENV{RUBYOPT} = '-rubygems -Isrc';
$ENV{PERL_UNICODE} = 'AS';
$ENV{HENZELL_ROOT} = '.';
$ENV{HENZELL_ALL_COMMANDS} = 'y';

my $irc = Henzell::IRCStub->new(channel => $CHANNEL);

my @services = (
  Henzell::SeenService->new(irc => $irc),
  Henzell::TellService->new(irc => $irc),
  Henzell::CommandService->new(irc => $irc, config => $CONFIG)
);
$irc->configure_services(services => \@services);

sub runcmd($) {
  chomp(my $cmd = shift);
  my $nick = $DEFAULT_NICK;
  return unless $cmd =~ /\S/;
  if ($cmd =~ /^(\w+): (.*)/) {
    $nick = $1;
    $cmd = $2;
  }

  $irc->tick();
  $irc->said({ who => $nick, channel => $CHANNEL, body => $cmd });
}

if (@ARGV > 0) {
  runcmd(join(' ', @ARGV));
  exit 0;
}

print "Henzell command runner\n";
while ( my $cmd = do { print "> "; <STDIN> } ) {
  runcmd($cmd);
}
