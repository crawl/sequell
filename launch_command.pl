#!/usr/bin/perl
use strict;
use warnings;

do 'game_parser.pl';

# possible paths of enhancement:
# read commands.txt

if (@ARGV == 0)
{
  die << "USAGE";
usage: $0 [-args] command args
  You should be able to use this just like a player in ##crawl, e.g.
  $0 gamesby toft
  $0 '!gamesby toft'

accepted arguments (these must come before the command name!):
  -h         run the command with the help flag on
  -p         run the command with the PM flag on
  -n         run the command with the notice flag on
  -a person  run the command as person (default $ENV{DUDE})
  -f         don't truncate after the first newline
USAGE
}

my $help = '';
my $pm   = '';
my $as   = $ENV{DUDE};
my $full = 0;

while (@ARGV && $ARGV[0] =~ /^-/)
{
  my $arg = shift;
  $help = 1, next if $arg =~ /-[^-]*h/;
  $pm   = 1, next if $arg =~ /-[^-]*p/;
  $pm   = 2, next if $arg =~ /-[^-]*n/;
  $full = 1, next if $arg =~ /-[^-]*f/;

  if ($arg =~ /-[^-]*a/ || $arg eq '--as')
  {
    $as = @ARGV ? shift : die "syntax: $0 -a person";
    next;
  }
  die "$0: unrecognized option $arg -- pass arguments to the command after specifying the command name\n";
}

my $command = shift;
$command =~ s/^!//;

# if the first command contains spaces, throw those spaces onto the beginning of ARGV
$command =~ s/ (.+)$// and do
{
  unshift @ARGV, split ' ', $1;
};

my $arg = join ' ', @ARGV;
$arg =~ y/'//d;
$as =~ y/'//d;

my $target = $arg;
$target =~ s/ .*$//;
$target =~ y/a-zA-Z0-9//cd;
$target =~ s/\d+$//;
$target = $as unless $target =~ /\S/;
$target =~ y/a-zA-Z0-9//cd;
$target =~ s/\d+$//;

if ($command =~ /\./)
{
  my ($command_name) = $command =~ /^(.+?)\./;
  my $output = qx('./commands/$command' '$target' '$as' '!$command_name $arg' '$help' '$pm');
  print "!$command_name: " if $help;
  print handle_output($output, $full) . "\n";
  exit;
}
else
{
  my @commands = map {s!^commands/!!; $_} <commands/*>;
  @commands = grep {index($_, $command) == 0} @commands;
  my @executable = grep {-x "commands/$_"} @commands;

  if (@commands > 1 && @executable == 1)
  {
    @commands = @executable;
    warn "$0: warning: multiple matches, but only one match is executable ($commands[0]), so I'm using that one.\n";
  }

  if (@commands > 1)
  {
    print "multiple matches:\n";
    print map {sprintf "  %s%s\n", $_, -x "commands/$_" ? "  (executable)" : ""} @commands;
  }
  elsif (@commands == 0)
  {
    print "no matches\n";
  }
  else
  {
    my ($command_name) = $commands[0] =~ /^(.+?)\./;
    print "!$command_name: " if $help;
    my $output = qx('./commands/$commands[0]' '$target' '$as' '!$command_name $arg' '$help' '$pm');
    print handle_output($output, $full) . "\n";
  }
}

