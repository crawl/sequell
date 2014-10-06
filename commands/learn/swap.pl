#!/usr/bin/perl
use strict;
use warnings;

use File::Spec;
use File::Basename;
use lib File::Spec->catfile(dirname(__FILE__), '../../lib');
use lib File::Spec->catfile(dirname(__FILE__), '../../src');
use LearnDB qw/check_entry_exists swap_entries report_error unquote
               $RTERM_INDEXED $RTERM/;
use Helper;
use utf8;
use open qw/:std :utf8/;

Helper::forbid_private();

eval {
  my $commandline = $ARGV[1];
  if ($commandline =~ /^$RTERM_INDEXED\s+$RTERM_INDEXED/) {
    my ($term, $num, $term2, $num2) = ($1, $2, $3, $4);
    $term = unquote($term);
    $term2 = unquote($term2);
    check_entry_exists($term, $num);
    check_entry_exists($term2, $num2);

    if (swap_entries($term, $num, $term2, $num2)) {
      print "Swapped $term"."[$num] with $term2"."[$num2].\n";
    } else {
      print "Failed to swap $term"."[$num] with $term2"."[$num2].\n";
    }
  } elsif ($commandline =~ /^$RTERM\s+$RTERM/) {
    my ($term1, $term2) = ($1, $2);
    unquote($_) for $term1, $term2;

    check_entry_exists($term1);
    check_entry_exists($term2);

    my $orig_term1count = LearnDB::num_entries($term1);
    my $orig_term2count = LearnDB::num_entries($term2);

    LearnDB::swap_terms($term1, $term2);

    my $new_term1count = LearnDB::num_entries($term1);
    my $new_term2count = LearnDB::num_entries($term2);
    print("$term1\[$orig_term1count], $term2\[$orig_term2count] => " .
          "$term2\[$new_term2count], $term1\[$new_term1count]\n");
  } else {
    my $cmd = "!learn swap";
    print "Syntax is: $cmd TERM1[NUM1] TERM2[NUM2] or $cmd TERM1 TERM2\n";
    exit 1;
  }
};
if ($@) {
  report_error($@);
}
