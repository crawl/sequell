package Henzell::Achieve;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw/achievement_name achievement_desc achievement_names
                    conduct_names conduct_name/;

my $ACHIEVEMENT_FILE = 'achieve.txt';
my $CONDUCT_FILE = 'conduct.txt';

my %ACHIEVEMENTS_BY_ID;
my %CONDUCTS_BY_ID;
my $ACHIEVEMENT_MAX_SHIFT = 0;
my $CONDUCT_MAX_SHIFT = 0;

sub each_line_of($$) {
  my ($file, $proc) = @_;
  open my $inf, '<', $file
    or die "Can't read $file: $!\n";
  while (<$inf>) {
    next unless /\S/ && !/^\s*#/;
    s/^\s+//, s/\s+$//;
    $proc->($_);
  }
  close $inf;
}

sub load_achievment_data() {
  each_line_of($ACHIEVEMENT_FILE,
               sub {
                 my $line = shift;
                 my ($shift, $name, $desc) =
                   ($line =~ /^(\d+)\s*=\s*(\S.*?\S)\s*;\s*(.*)/);
                 $ACHIEVEMENTS_BY_ID{1 << $shift} = {
                                                     name => $name,
                                                     desc => $desc
                                                    };
                 if ($shift > $ACHIEVEMENT_MAX_SHIFT) {
                   $ACHIEVEMENT_MAX_SHIFT = $shift
                 }
               });
}

sub load_conduct_data() {
  each_line_of($CONDUCT_FILE,
               sub {
                 my $line = shift;
                 my ($shift, $name) = $line =~ /^(\d+)\s*=\s*(.*)/;
                 $CONDUCTS_BY_ID{1 << $shift} = $name;
                 if ($shift > $CONDUCT_MAX_SHIFT) {
                   $CONDUCT_MAX_SHIFT = $shift;
                 }
               });
}

sub achievement_names($) {
  my $ids = shift;
  my @names;
  for my $i (0 .. $ACHIEVEMENT_MAX_SHIFT) {
    my $id = 1 << $i;
    push @names, achievement_name($id) if $ids & $id;
  }
  @names
}

sub achievement_name($) {
  my $id = shift;
  $ACHIEVEMENTS_BY_ID{$id}{name} || '?'
}

sub achievement_desc($) {
  my $id = shift;
  $ACHIEVEMENTS_BY_ID{$id}{desc} || sprintf("achieved %x", $id)
}

sub conduct_names($) {
  my $ids = shift;
  my @conducts;
  for my $i (0 .. $CONDUCT_MAX_SHIFT) {
    my $id = 1 << $i;
    push @conducts, conduct_name($id) if $ids & $id;
  }
  @conducts
}

sub conduct_name($) {
  my $id = shift;
  $CONDUCTS_BY_ID{$id} || '?'
}

load_achievment_data();
load_conduct_data();

1
