package Henzell::Root;

use strict;
use warnings;

use File::Spec;

sub root($) {
  my $root = $ENV{HENZELL_ROOT} || '.';
  my $path = shift;
  $path ? File::Spec->join($root, $path) : $root
}

1
