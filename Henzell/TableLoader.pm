=head1 TableLoader

Given an xlog hash, inserts a row into a table. Should be created up-front and
cached rather than created per-row.

=cut

package Henzell::TableLoader;

use strict;
use warnings;

use Henzell::Table;
use Tie::Cache;

my %fk_cache;

tie %fk_cache, 'Tie::Cache', { MaxCount => 50000,
                               MaxBytes => 20 * 1024 * 1024 };

# Required parameters:
# - dbh
# - table
# - base
sub new {
  my ($cls, %config) = @_;
  my $self = bless \%config, $cls;
  $self->_init();
  $self
}

sub _init {
  my $self = shift;
  $self->{_table} = Henzell::Table->new($self->{table}, $self->{base});
  $self->{_fieldset} = $self->{_table}->fieldset();
  $self->{_insert_fields} =
    [grep(!$_->primary_key(), $self->{_fieldset}->columns())];
  $self->{_fk} =
    [grep($_->foreign_key(), @{$self->{_insert_fields}})];
}

sub insert_lookup_record {
  my ($self, $fk, $value) = @_;

  my $lookup_table = $fk->lookup_table();
  $lookup_table->lookup_value_id($self->{db}, $value)
}

# Note: Simplifying assumption is that foreign key lookups are only
# for stringy values.
sub resolve_foreign_key {
  my ($self, $fk, $g) = @_;
  my $value = $g->{$fk->name()} || '';
  my $ref_key = $fk->name() . ":" . lc($value);
  my $ref_value = $fk_cache{$ref_key};
  if (!$ref_value) {
    $ref_value = $self->insert_lookup_record($fk, $value);
    $fk_cache{$ref_key} = $ref_value;
  }
  #print STDERR "Resolved " . $fk->name() . ": $value to $ref_value\n";
  $ref_value->{id}
}

sub resolve_foreign_keys {
  my ($self, $g) = @_;
  for my $fk (@{$self->{_fk}}) {
    $g->{$fk->name()} = $self->resolve_foreign_key($fk, $g);
  }
}

sub bind_values {
  my ($self, $g) = @_;
  map($_->sql_value($$g{$_->name()}), @{$self->{_insert_fields}})
}

sub insert {
  my ($self, $xlog_ref) = @_;
  my %xlog_hash = %$xlog_ref;
  $self->resolve_foreign_keys(\%xlog_hash);
  my $st = $self->insert_statement();
  my @bind_values = $self->bind_values(\%xlog_hash);
  $st->execute(@bind_values) or
    die("Couldn't insert " . join(", ", @bind_values) .
        " into $self->{table} with " . $self->insert_sql() . ": $!\n");
}

sub insert_statement {
  my $self = shift;
  ($self->{_insert_st} ||= $self->{db}->prepare($self->insert_sql()))
    or die "Can't prepare: " . $self->insert_sql() . ": $!\n";
}

sub insert_sql {
  my $self = shift;
  my $table = $self->{table};
  my @columns = @{$self->{_insert_fields}};
  my $column_list = join(", ", map($_->sql_ref_name(), @columns));
  my $placeholder_list = join(", ", map($_->sql_ref_placeholder(), @columns));
  <<INSERT_SQL
INSERT INTO $table ($column_list) VALUES ($placeholder_list)
INSERT_SQL
}

1
