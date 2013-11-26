package LearnDB::Entry;

use strict;
use warnings;

use overload fallback => 1,
  '""' => sub { shift()->description() };

sub wrap {
  my ($cls, $obj) = @_;
  return $obj if ref($obj) eq $cls;
  $cls->new(term => '', index => -1, count => -1, value => $obj)
}

sub new {
  my ($cls, %opt) = @_;
  bless \%opt, $cls
}

sub bare {
  my $self = shift;
  $self->term() eq '' || $self->value() =~ /^\s*: /
}

sub strip_value {
  my ($self, $value) = @_;
  $value =~ s/^\s*: //;
  $value
}

sub template {
  my $self = shift();
  $self->bare() ? $self->formatted_value() : $self->description()
}

sub term {
  shift()->{term}
}

sub value {
  shift()->{value}
}

sub formatted_value {
  my $self = shift;
  $self->strip_value($self->value())
}

sub index {
  shift()->{index}
}

sub count {
  shift()->{count}
}

sub description {
  my $self = shift;
  my ($term, $index, $count, $value) = ($self->term(), $self->index(),
                                        $self->count(), $self->value());
  return $value if $term eq '';
  "$term\[$index/$count]: $value"
}

1
