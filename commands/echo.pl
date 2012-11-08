#! /usr/bin/perl

use strict;
use warnings;

use lib "src";
use Helper;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
chomp(my @args = <STDIN>);
help("Echoes the command to the channel");
print "$args[1] said: $args[2]";
