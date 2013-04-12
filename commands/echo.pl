#! /usr/bin/perl

use strict;
use warnings;

use lib "src";
use Encode qw/decode/;
use Helper;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
help("Echoes the command to the channel");

my $cmd = decode('UTF-8', $ARGV[2]);
$cmd =~ s/^\S+\s*//;
print "$cmd\n";
