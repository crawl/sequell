#! /usr/bin/perl

use strict;
use warnings;

use lib 'commands/learn';
use LearnDB;

our $RTERM_INDEXED;
our $RTERM;
our $RTEXT;

eval {
  if ($ARGV[1] =~ /^$RTERM_INDEXED $RTEXT/) {
    print insert_entry($1, $2, $3);
  } elsif ($ARGV[1] =~ /^$RTERM $RTEXT/) {
    print insert_entry($1, -1, $2);
  } else {
    print "Syntax is: !learn $0 TERM TEXT or !learn $0 TERM[n] TEXT\n";
    exit 1;
  };
};
if ($@) {
  print "$@";
};
