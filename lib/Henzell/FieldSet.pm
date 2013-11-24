package Henzell::FieldSet;

use strict;
use warnings;

use Henzell::Crawl;
use Henzell::Column;

sub new {
  my ($cls, $table) = @_;
  my $self = bless {
                    _table => $table
                   }, $cls;
  $self->load();
  $self
}

sub load {
  my $self = shift;
  my $table = $self->{_table};
  $self->{_raw_columns} = [Henzell::Crawl::config_list("${table}-fields-with-type")];
  $self->{_columns} = [map { Henzell::Column->new($_) } @{$self->{_raw_columns}}];
  $self->{_column_map} = map { ($_->name()) => $_ } @{$self->{_columns}};
}

sub columns {
  my $self = shift;
  @{$self->{_columns}}
}

sub primary_key {
  my $self = shift;
  $self->{_pk} ||= $self->_find_primary_key();
}

sub _find_primary_key {
  my $self = shift;
  for my $col (@{$self->{_columns}}) {
    return $col if $col->primary_key();
  }
}

sub column {
  my ($self, $column) = @_;
  $self->{_column_map}{$column}
}

1
