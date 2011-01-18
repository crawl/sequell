#! /usr/bin/perl

use strict;
use warnings;

use Henzell::Cmd qw/load_all_commands execute_cmd/;

print "Henzell command runner\n";
Henzell::Cmd::load_all_commands();
while ( my $cmd = do { print "> "; <STDIN> } ) {
  chomp($cmd);
  my ($exit, $result) = Henzell::Cmd::execute_cmd('nobody', $cmd);
  print "$result\n";
}
