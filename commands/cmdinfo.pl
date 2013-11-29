#! /usr/bin/env perl

use strict;
use warnings;

use lib 'lib';
use lib 'src';
use Henzell::Config qw/%CMDPATH/;
use Helper;

help("Lists available Henzell commands");

Henzell::Config::read();
print(join(' ', sort keys %CMDPATH));
