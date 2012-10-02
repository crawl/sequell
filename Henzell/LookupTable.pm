package Henzell::LookupTable;

use strict;
use warnings;

sub new {
  my ($cls, %props) = @_;
  bless \%props, $cls
}

sub name {
  my $self = shift;
  "l_" . $self->{name}
}

sub ddl {
  my $self = shift;
  my $name = $self->name();
  <<DDL
CREATE TABLE $name (
  @{[join(",\n  ", $self->column_defs())]}
)
DDL
}

sub fields {
  my $self = shift;
  @{$self->{fields}}
}

sub column_def {
  my ($self, $field) = @_;
  $field->sql_name() . " " . $field->sql_type() . " UNIQUE"
}

sub column_defs {
  my $self = shift;
  ("id SERIAL",
   map($self->column_def($_), ($self->fields())[0]))
}

1
