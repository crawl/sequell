#! /usr/bin/perl

use strict;
use warnings;

use lib "src";
use Helper;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
help("Echoes the command to the channel");

my $cmd = $ARGV[2];
$cmd =~ s/^\S+ //;
print "$cmd\n";
