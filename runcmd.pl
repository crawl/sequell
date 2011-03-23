#! /usr/bin/perl

use strict;
use warnings;

use Henzell::Cmd qw/load_all_commands execute_cmd/;

Henzell::Cmd::load_all_commands();

sub runcmd($) {
  chomp(my $cmd = shift);
  my ($exit, $result) = Henzell::Cmd::execute_cmd('nobody', $cmd);
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
