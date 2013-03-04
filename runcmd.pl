#! /usr/bin/perl

use strict;
use warnings;

use Henzell::Cmd qw/load_all_commands execute_cmd/;
do 'sqllog.pl';

my $DEFAULT_NICK = $ENV{NICK} || 'greensnark';

$ENV{IRC_NICK_AUTHENTICATED} = 'y';
$ENV{HENZELL_SQL_QUERIES} = 'y';
$ENV{RUBYOPT} = '-rubygems -Isrc';
$ENV{HENZELL_ROOT} = '.';
Henzell::Cmd::load_all_commands();

sub runcmd($) {
  chomp(my $cmd = shift);
  my $nick;
  return unless $cmd =~ /\S/;
  if ($cmd =~ /^(\w+): (.*)/) {
    $nick = $1;
    $cmd = $2;
  }
  my ($exit, $result) =
    Henzell::Cmd::execute_cmd($nick || $DEFAULT_NICK, $cmd, 1);
  print handle_output($result, 1), "\n";
}

if (@ARGV > 0) {
  runcmd(join(' ', @ARGV));
  exit 0;
}

print "Henzell command runner\n";
while ( my $cmd = do { print "> "; <STDIN> } ) {
  runcmd($cmd);
}
