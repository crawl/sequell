package Henzell::FSLearnDB;

use strict;
use warnings;

use File::Basename;
use File::Spec;

sub new {
  my ($cls, $dir) = @_;
  bless { dir => $dir }, $cls
}

sub cleanse_term
{
  my $term = lc(shift);

  $term =~ y/ /_/;
  $term =~ s/^_+//;
  $term =~ s/_+$//;

  $term =~ y/a-z0-9_!//cd;
  return $term;
}

sub num_entries
{
  my ($self, $term) = @_;
  $term = cleanse_term($term);

  return 0 unless $term;
  opendir(my $dir, term_directory($term)) or return 0;
  my @files = grep {$_ ne "." and $_ ne ".." and $_ ne "contrib"}
              readdir $dir;
  return scalar @files;
}

sub dir {
  shift()->{dir}
}

sub _term_dirs {
  glob(shift()->dir() . "/*")
}

sub term_dir {
  my ($self, $term) = @_;
  File::Spec->catfile($self->dir(), cleanse_term($term))
}

sub entry_file {
  my ($self, $term, $entry) = @_;
  File::Spec->catfile($self->term_dir($term), $entry || '1')
}

sub term_count {
  my $self = shift;
  my @files = $self->_term_dirs();
  scalar(@files)
}

sub definition_count {
  my ($self, $term) = @_;

  if ($term) {
    my $dir = $self->term_dir($term);
    my $entry = 1;
    while (1) {
      unless (-r $self->entry_file($term, $entry)) {
        return $entry - 1;
      }
      ++$entry;
    }
  } else {
    my $total = 0;
    for my $term_dir ($self->_term_dirs()) {
      my $term = basename($term_dir);
      $total += $self->definition_count($term) if $term;
    }
    $total
  }
}

sub each_term {
  my ($self, $action) = @_;
  for my $term_dir ($self->_term_dirs()) {
    my $term = cleanse_term(basename($term_dir));
    $action->($term);
  }
}

sub definition {
  my ($self, $term, $index) = @_;
  $term = cleanse_term($term);
  $index ||= 1;
  my $num_entries;
  if ($index > 1 || $index < 0) {
    $num_entries = $self->definition_count($term);
    $index = $num_entries if $index > $num_entries;
    $index += $num_entries + 1 if $index < 0;
  }
  return undef if $index < 1;

  my $entry_file = $self->entry_file($term, $index);
  return undef unless -r $entry_file;
  open my $fh, '<', $entry_file or return undef;
  my $text = do { local $/; <$fh> };
  chomp $text;
  $text
}

sub definitions {
  my ($self, $term) = @_;
  my $num_entries = $self->definition_count($term);
  my @entries;
  for my $entry (1 .. $num_entries) {
    my $entry_text = $self->definition($term, $entry);
    last unless defined $entry_text;
    push @entries, $entry_text;
  }
  @entries
}

1
