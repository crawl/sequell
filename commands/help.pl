#!/usr/bin/perl
do 'commands/helper.pl';

help("Displays help on a command. For a list of commands, see !cmdinfo.");

# prep the new @ARGV for the help command
$ARGV[3] = 1;
$ARGV[2] =~ s/^!help\s+//i;
$ARGV[2] = "!$ARGV[2]" unless substr($ARGV[2], 0, 1) eq '!';

# which command are we going for?
$ARGV[2] =~ /(\S+)/;
my $requested = defined($1) ? $1 : "!help";

# find the command in commands.txt
open my $handle, '<', 'commands/commands.txt' or print "Unable to open commands/commands.txt: $!" and exit;
while (<$handle>)
{
  my ($command, $file) = /^(\S+)\s+(.+)$/;
  $file = "commands/$file";
  if ($requested eq lc($command))
  {
      print "$command: ";
      exec $file, @ARGV;
  }
}

print "Unable to find help on $requested.";

