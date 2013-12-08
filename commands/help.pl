#!/usr/bin/perl

use lib 'src';
use Helper;
use Henzell::Config qw/%CMDPATH/;
use LearnDB;

Helper::help("Displays help on a command. For a list of commands, see !cmdinfo.");

Henzell::Config::read();

my $sigils = Henzell::Config::sigils();

# prep the new @ARGV for the help command
$ARGV[3] = 1;
$ARGV[2] =~ s/^!help\s+//i;
$ARGV[2] = "!$ARGV[2]" unless !$ARGV[2] || substr($ARGV[2], 0, 1) =~ /[\Q$sigils\E]/;

# which command are we going for?
$ARGV[2] =~ /(\S+)/;
my $requested = lc(defined($1) ? $1 : "!help");

if ($CMDPATH{$requested}) {
  print "$requested: ";
  exec $CMDPATH{$requested}, @ARGV;
} else {
  print "[[[LEARNDB: ${requested}: :::!help:${requested}:::No help for $requested (you could add help with !learn add !help:$requested <helpful text>)]]]\n"
}
