package Henzell::SeenService;

use strict;
use warnings;

sub new {
  my ($cls, %opt) = @_;
  bless { irc => $opt{irc} }, $cls
}

1
