#!/usr/bin/perl
use strict;
use warnings;

use lib "commands/learn";
use LearnDB qw/query_entry parse_query/;

my ($term, $num) = parse_query($ARGV[1]);
exit 0 unless $term =~ /\S/;
if (defined $num)
{
  my $entry = query_entry($term, $num);
  if ($entry eq '')
  {
	if ($num == 1) {
	  print "I don't have a page labeled $term in my learndb.";
	}
	else {
	  print "I don't have a page labeled $term\[$num] in my learndb.";
	}
  }
  else
  {
    print $entry;
  }
}
