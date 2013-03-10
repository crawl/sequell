package Henzell::IRC;

use strict;
use warnings;

sub cleanse_nick {
  my $nick = shift;
  $nick =~ tr{'<>/}{}d;
  $nick
}

1
