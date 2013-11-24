#! /usr/bin/perl

use strict;
use warnings;

use lib "commands/learn";
use LearnDB qw/$RTERM_INDEXED $RTERM $RTEXT report_error insert_entry/;
use File::Basename;

eval {
  if ($ARGV[1] =~ /^$RTERM_INDEXED $RTEXT/) {
    print insert_entry($1, $2, $3);
  } elsif ($ARGV[1] =~ /^$RTERM $RTEXT/) {
    print insert_entry($1, -1, $2);
  } else {
    (my $cmd = basename($0)) =~ s/\.pl$//;
    print "Syntax is: !learn $cmd TERM TEXT or !learn $cmd TERM[n] TEXT\n";
    exit 1;
  };
};
if ($@) {
  report_error $@;
};
