#!/usr/bin/perl
use strict;
use warnings;

use lib 'commands/learn';
use LearnDB;

my ($term, $num, $term2, $num2) =
    $ARGV[1] =~ /^([\w! ]+)\[(\d+)\] +([\w! ]+)\[(\d+)\]/ or do
{
  print "Syntax is: !learn swap TERM[NUM] TERM2[NUM2]";
  exit;
};

if (num_entries($term) < $num) {
  print "I don't have a page labeled $term\[$num] in my learndb.";
  exit;
}

if (num_entries($term2) < $num2) {
  print "I don't have a page labeled $term2\[$num2] in my learndb.";
  exit;
}

if (swap_entries($term, $num, $term2, $num2)) {
  print "Swapped $term"."[$num] with $term2"."[$num2].\n";
}
else {
  print "Failed to swap $term"."[$num] with $term2"."[$num2].\n";
}
