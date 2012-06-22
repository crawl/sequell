use strict;
use warnings;

package Henzell::Crawl;

use base 'Exporter';
our @EXPORT_OK = qw/canonical_place_name/;

use YAML::Any qw/LoadFile/;

my $CONFIG_FILE = 'commands/crawl-data.yml';
my $CRAWLDATA = LoadFile($CONFIG_FILE);

my %UNIQUES = map(($_ => 1), @{$$CRAWLDATA{uniques}});
my %ORCS = map(($_ => 1), @{$$CRAWLDATA{orcs}});

sub crawl_unique {
  my $name = shift;
  $UNIQUES{$name}
}

sub known_orc {
  my $name = shift;
  $ORCS{$name}
}

sub possible_pan_lord {
  my $name = shift;
  !/^(?:an?|the) / && !crawl_unique($name) && !known_orc($name)
}

sub canonical_place_name {
  my $place = shift;
  return unless $place;

  $place =~ s/^Vault:/Vaults:/i;
  $place =~ s/^Shoal:/Shoals:/;
  $place
}

1
