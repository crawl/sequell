#!/usr/bin/perl
use strict;
use warnings;

use File::Spec;
use File::Basename;
use lib File::Spec->catfile(dirname(__FILE__), '../../lib');
use lib File::Spec->catfile(dirname(__FILE__), '../../src');
use LearnDB qw/check_entry_exists swap_entries report_error/;
use Helper;

Helper::forbid_private();

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
