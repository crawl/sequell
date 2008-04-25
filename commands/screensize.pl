#!/usr/bin/perl
use strict;
use warnings;
do 'commands/helper.pl';

help("Displays the screen size of a currently active player.");

my $nick = lc($ARGV[0]);
my $inprogpath = '/home/crawl/chroot/dgldir/inprogress-crawl02';

opendir my $handle, $inprogpath or die "Unable to opendir $inprogpath: $!";

foreach (readdir $handle)
{
  if (/^([^:]+):/)
  {
    if (lc($1) eq $nick)
    {
      my @lines = do {local @ARGV = "$inprogpath/$_"; <>};
      chomp $lines[1];
      chomp $lines[2];
      print "$1 is playing at $lines[2]x$lines[1].\n";
      exit;
    }
  }
}

print "I don't see $ARGV[0] playing right now.\n";

