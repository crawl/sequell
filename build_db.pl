#! /usr/bin/perl

use strict;
use warnings;

require 'sqllog.pl';

my @LOGS = ('allgames.txt');

for my $log (@LOGS) {
  open my $inf, '<', $log or die "Can't read $log: $!\n";
  cat_logfile($log, 'cao', $inf) ||
    cat_logfile($log, 'cao', $inf, -1);
}
