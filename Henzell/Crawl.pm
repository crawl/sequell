use strict;
use warnings;

package Henzell::Crawl;

use base 'Exporter';
our @EXPORT_OK = qw/canonical_place_name/;

sub canonical_place_name {
  my $place = shift;
  return unless $place;

  $place =~ s/^Vault:/Vaults:/i;
  $place =~ s/^Shoal:/Shoals:/;
  $place
}

1
