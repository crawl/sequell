#!/usr/bin/perl
use strict;
use warnings;

use File::Spec;
use File::Basename;
use lib File::Spec->catfile(dirname(__FILE__), '../../lib');
use LearnDB qw/query_entry parse_query/;
use utf8;
use open qw/:std :utf8/;

my ($term, $num) = parse_query($ARGV[1]);
print(query_entry($ARGV[1], undef, 'error_if_missing', 'no_redirect') || '');
