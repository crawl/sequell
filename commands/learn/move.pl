#! /usr/bin/perl

use strict;
use warnings;

# !learn move may be used as:
#  move A[x] B[y] -> delete A[x] and !learn add B[y] <text>
#  move A[x] B    -> delete A[x] !learn add B <text>, i.e. add as last entry.
#  move A B       -> rename all entries in A as B

use File::Spec;
use File::Basename;
use lib File::Spec->catfile(dirname(__FILE__), '../../lib');
use lib File::Spec->catfile(dirname(__FILE__), '../../src');
use LearnDB qw/$RTERM_INDEXED $RTERM/;
use Helper;

Helper::forbid_private();

eval {
  if ($ARGV[1] =~ /^$RTERM_INDEXED\s+$RTERM_INDEXED\s*$/) {
    print(LearnDB::move_entry($1, $2, $3, $4));
  }
  elsif ($ARGV[1] =~ /^$RTERM_INDEXED\s+$RTERM\s*$/) {
    print(LearnDB::move_entry($1, $2, $3));
  }
  elsif ($ARGV[1] =~ /^$RTERM\s+$RTERM\s*$/) {
    print(LearnDB::move_entry($1, undef, $2));
  }
  else {
    print "Syntax: !learn $0 SRC[x] DST[y] or SRC[x] DST or SRC DST\n";
  }
};
if ($@) {
  LearnDB::report_error($@);
}
