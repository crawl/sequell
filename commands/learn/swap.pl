#!/usr/bin/perl
use strict;
use warnings;

use lib "src"learn';
use LearnDB;

eval {
  my ($term, $num, $term2, $num2) =
    $ARGV[1] =~ /^([\w! ]+)\[(\d+)\] +([\w! ]+)\[(\d+)\]/ or do
      {
        print "Syntax is: !learn swap TERM[NUM] TERM2[NUM2]";
        exit;
      };

  check_entry_exists($term, $num);
  check_entry_exists($term2, $num2);

  if (swap_entries($term, $num, $term2, $num2)) {
    print "Swapped $term"."[$num] with $term2"."[$num2].\n";
  } else {
    print "Failed to swap $term"."[$num] with $term2"."[$num2].\n";
  }
};
if ($@) {
  report_error($@);
}
