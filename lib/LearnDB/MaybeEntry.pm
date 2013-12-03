package LearnDB::MaybeEntry;

use strict;
use warnings;

use lib 'lib';
use LearnDB::Entry;

use overload fallback => 1,
  '""' => sub { shift()->description() };

sub with_err {
  my ($cls, $err) = @_;
  return $err if ref($err) eq $cls;
  $cls->new(err => $err)
}

sub with_entry {
  my ($cls, $entry) = @_;
  return $entry if ref($entry) eq $cls;
  $cls->new(entry => LearnDB::Entry->wrap($entry))
}

sub new {
  my ($cls, %opt) = @_;
  bless \%opt, $cls
}

sub err {
  shift()->{err}
}

sub entry {
  shift()->{entry}
}

sub description {
  my $self = shift;
  return $self->{err} if $self->{err};
  $self->{entry}->description()
}

1
