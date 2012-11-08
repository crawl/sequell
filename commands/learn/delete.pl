#!/usr/bin/perl
use strict;
use warnings;

use lib "src"learn';
use LearnDB;

$ARGV[1] =~ y/ /_/;
$ARGV[1] =~ /^([\w!]+)(?:\[(\d+)\])?/ or do
{
  print "Syntax is: !learn delete TERM[NUM] (you may omit [NUM] if TERM has only one entry)";
  exit;
};

my ($term, $num) = (cleanse_term($1), $2);

my $entries = num_entries($term);
$num = 1 if $entries == 1;

if ($entries == 0)
{
  print "That's easy, $term doesn't even exist!";
}
elsif (!defined($num)) # if $entries == 1, $num is defined
{
  print "$term has $entries entries, you can only delete one at a time.";
}
elsif ($num > $entries)
{
  print "$term has only $entries entr".($entries==1?"y":"ies").".";
}
else
{
  my $text = read_entry($term, $num);
  del_entry($term, $num);
  print "Deleted $text";
}
