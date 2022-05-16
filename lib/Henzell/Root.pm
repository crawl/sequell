package Henzell::Root;

use strict;
use warnings;

use File::Spec qw/join/;

sub root($) {
  my $root = $ENV{HENZELL_ROOT} || '.';
  my $path = shift;
  $path ? join($root, $path) : $root
}

1
