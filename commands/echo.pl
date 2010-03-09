#! /usr/bin/perl

use strict;
use warnings;

use lib 'commands';
use Helper;

help("Echoes the command to the channel");
print "$ARGV[1] said: $ARGV[2]";
