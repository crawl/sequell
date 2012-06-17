#! /usr/bin/perl

use strict;
use warnings;

use Henzell::Cmd qw/load_all_commands execute_cmd/;

my $DEFAULT_NICK = 'greensnark';

$ENV{IRC_NICK_AUTHENTICATED} = 'y';
Henzell::Cmd::load_all_commands();

sub runcmd($) {
  chomp(my $cmd = shift);
  my $nick;
  if ($cmd =~ /^(\w+): (.*)/) {
    $nick = $1;
    $cmd = $2;
  }
  my ($exit, $result) = Henzell::Cmd::execute_cmd($nick || $DEFAULT_NICK, $cmd);
  chomp $result;
  print "$result\n";
}

if (@ARGV > 0) {
  runcmd(join(' ', @ARGV));
  exit 0;
}

print "Henzell command runner\n";
while ( my $cmd = do { print "> "; <STDIN> } ) {
  runcmd($cmd);
}
