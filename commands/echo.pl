#! /usr/bin/perl

use strict;
use warnings;

use lib "src";
use Helper;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
help("Echoes the command to the channel");
print "$ARGV[2]\n";
