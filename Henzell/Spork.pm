package Henzell::Spork;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw/spork_wishtracker_xdict/;

sub strip_meta_info($) {
  my $line = shift;
  $line =~ s/\([^\)]*wish|T:[^\)]*\)$//;
  $line
}

sub parse_wish($$) {
  my ($g, $line) = @_;
  if ($line =~/(\w+) wished for (.*)/) {
    $$g{mtype} = 'wish';
    $$g{mobj} = $2;
  }
}

sub parse_amulet_pickup($$) {
  my ($g, $line) = @_;
  if ($line =~ /(\w+) picked up (.*) in (.*) on/) {
    $$g{mtype} = 'achieve';
    $$g{mobj}  = 'amulet';
    $$g{placename} = $3;
  }
}

sub plane_name($) {
  my $plane = shift;
  if ($plane =~ /plane of (.*)/i) {
    return $1;
  } elsif ($plane =~ /the (\w+) plane/i) {
    return $1;
  }
  $plane
}

sub parse_elemental_plane($$) {
  my ($g, $line) = @_;
  if ($line =~ /(\w+) just entered (.*) on/) {
    $$g{mtype} = 'plane';

    my $plane = $2;
    $$g{mobj} = plane_name($plane);
    $$g{placename} = $plane;
  }
}

sub parse_lifesave($$) {
  my ($g, $line) = @_;
  if ($line =~ /(\w+) lifesaved instead of being killed by (.*) on/) {
    $$g{mtype} = 'lifesaved';
    $$g{mobj} = $2;
  }
}

sub spork_wishtracker_xdict($) {
  my $line = shift;

  my %g;
  $g{wish_count} = $1 if $line =~ /(\d+)[a-z]{2} wish/i;
  $g{turns} = $1 if $line =~ /T:(\d+)/;
  $g{turns} = $1 if $line =~ /^Turn (\d+):/;

  $line =~ s/^Turn \d+: //;
  $line = strip_meta_info($line);

  $g{name} = $1 if $line =~ /^(\w+)/;
  ($g{mdesc} = $line) =~ s/^\w+ //;

  parse_wish(\%g, $line);
  parse_amulet_pickup(\%g, $line);
  parse_elemental_plane(\%g, $line);
  parse_lifesave(\%g, $line);

  $g{mtype_finished} = 1;

  \%g
}

1
