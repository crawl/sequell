#! /usr/bin/env perl

use strict;
use warnings;

use Henzell::Config qw/%CMDPATH/;
use lib 'src';
use Helper;

help("Lists available Henzell commands");

Henzell::Config::read();
print(join(' ', sort keys %CMDPATH));
