use strict;
use warnings;

package Henzell::Crawl;

use base 'Exporter';
our @EXPORT_OK = qw/canonical_place_name/;

use YAML::Any qw/LoadFile/;
use File::Spec;
use File::Basename;

my $HENZELL_ROOT = File::Spec->catfile(File::Basename::dirname(__FILE__), '..');
my $CONFIG_FILE =
  File::Spec->catfile($HENZELL_ROOT, 'config/crawl-data.yml');

my $CRAWLDATA = LoadFile($CONFIG_FILE);

my %UNIQUES = map(($_ => 1), @{$$CRAWLDATA{uniques}});
my %ORCS = map(($_ => 1), @{$$CRAWLDATA{orcs}});
my %GOD_ALIASES = %{$$CRAWLDATA{'god-aliases'}};

sub version_qualifier_numberize {
  my $qualifier = shift;
  return 999 * 999 unless $qualifier;
  my ($prefix, $index) = $qualifier =~ /^([a-z]+)([0-9]*)/;
  $index = '0' if !defined($index) || $index eq '';
  1000 * ord($prefix) + $index
}

my %vnum_cache;
sub version_numberize {
  my $v = shift;

  my $cached_result = $v && $vnum_cache{$v};
  return $cached_result if $cached_result;

  my ($version, $qualifier) = split(/-/, $v);
  $qualifier ||= '';
  my @version_pieces = split(/\./, $version);
  if (@version_pieces < 4) {
    @version_pieces = (@version_pieces, ('0') x (4 - @version_pieces));
  }
  my $base = 1_000_000;
  my $number = 0;
  for my $version_piece (reverse @version_pieces) {
    $number += $base * $version_piece;
    $base   *= 1000;
  }
  my $result = $number + version_qualifier_numberize($qualifier);
  $vnum_cache{$v} = $result;

  $result
}

# Cleans up the given version number, ensuring it's at least a dotted triple.
# 0.10 -> 0.10.0
# 0.9-b1 -> 0.9.0-b1
# 0.3.5 -> 0.3.5
sub canonical_version {
  my $v = shift;
  $v =~ s/^(\d+\.\d+)($|[^\d.])/$1.0$2/;
  $v
}

sub decorated_fields {
  my $property_name = shift;
  map {
    my $field = $_;
    $field =~ s/[*?]+//g;
    $field
  } @{$$CRAWLDATA{$property_name}}
}

sub indexed_fields {
  my $property = shift;
  map {
    my $field = $_;
    $field =~ s/[ID*?]+//g;
    $field
  } (grep /\?/, $$CRAWLDATA{$property})
}

sub logfields_decorated {
  decorated_fields('logrecord-fields-with-type')
}

sub milefields_decorated {
  decorated_fields('milestone-fields-with-type')
}

sub config_item {
  my $config_name = shift;
  $$CRAWLDATA{$config_name} or die "Can't find config_item: $config_name\n"
}

sub config_hash {
  %{config_item(@_)}
}

sub config_list {
  @{config_item(@_)}
}

sub game_type_prefixes {
  config_hash('game-type-prefixes')
}

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

sub canonical_god_name {
  my $name = shift;
  return '' unless $name;
  $GOD_ALIASES{lc($name)} || $name
}

sub canonical_place_name {
  my $place = shift;
  return unless $place;

  $place =~ s/^Vault\b/Vaults/i;
  $place =~ s/^Shoal\b/Shoals/;
  $place
}

1
