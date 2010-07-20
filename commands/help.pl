#!/usr/bin/perl
do 'commands/helper.pl';
use Henzell::Config qw/%CMDPATH/;

help("Displays help on a command. For a list of commands, see !cmdinfo.");

Henzell::Config::read();

# prep the new @ARGV for the help command
$ARGV[3] = 1;
my ($key) = $ARGV[2] =~ /^(.)help/i;

$ARGV[2] =~ s/^.help\s+//i;
$ARGV[2] = "$key$ARGV[2]" unless !$ARGV[2] || substr($ARGV[2], 0, 1) eq $key;

# which command are we going for?
$ARGV[2] =~ /(\S+)/;
my $requested = lc(defined($1) ? $1 : "${key}help");

if ($CMDPATH{$requested}) {
  exec $CMDPATH{$requested}, @ARGV;
}
