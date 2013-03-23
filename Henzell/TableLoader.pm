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
  $self->{_real_fields} =
    [grep(!$_->virtual_column(), @{$self->{_insert_fields}})];
  $self->{_fk} =
    [grep($_->foreign_key(), @{$self->{_insert_fields}})];
  $self->{_virtual} =
    [grep($_->virtual_column(), @{$self->{_insert_fields}})];
}

sub table_name {
  shift()->{_table}->name()
}

sub table {
  shift()->{_table}
}

sub insert_lookup_record {
  my ($self, $fk, $value) = @_;
  my $lookup_table = $fk->lookup_table();
  $lookup_table->lookup_value_id($self->{db}, $value)
}

# Note: Simplifying assumption is that foreign key lookups are only
# for stringy values.
sub resolve_foreign_key {
  my ($self, $fk, $value) = @_;
  my $canonical_value = $fk->case_sensitive()? $value : lc($value);
  my $ref_key = $fk->name() . ":" . $canonical_value;
  my $ref_value = $fk_cache{$ref_key};
  if (!$ref_value) {
    $ref_value = $self->insert_lookup_record($fk, $value);
    $fk_cache{$ref_key} = $ref_value;
  }
  #print STDERR "Resolved " . $fk->name() . ": $value to $ref_value\n";
  $ref_value->{id}
}

sub strip_string {
  my $string = shift;
  s/^\s+//, s/\s+$// for $string;
  $string
}

sub canonicalize_multivalue {
  my ($delimiter, $value) = @_;
  my %dedupe;
  my @pieces = sort(grep(!$dedupe{$_}++,
                         map(strip_string($_),
                             split(/\Q$delimiter/, $value))));
  join($delimiter, @pieces)
}

sub resolve_foreign_keys {
  my ($self, $g) = @_;
  for my $fk (@{$self->{_fk}}) {
    my $value = $g->{$fk->name()} || '';
    if ($fk->multivalued()) {
      $value = canonicalize_multivalue($fk->value_delimiter(), $value);
    }
    $g->{$fk->name()} = $self->resolve_foreign_key($fk, $value);
  }
}

sub bind_values {
  my ($self, $g) = @_;
  map($_->sql_value($$g{$_->name()}), @{$self->{_real_fields}})
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
  my $id = $self->{db}->last_insert_id(undef, undef,
                                       $self->table_name(), undef);
  $self->insert_join_table_values($id, \%xlog_hash);
  $id
}

sub insert_join_table_values {
  my ($self, $id, $g) = @_;
  for my $virtual_column (@{$self->{_virtual}}) {
    my $virtual_ids = $g->{$virtual_column->name()};
    next unless $virtual_ids;
    my $st = $self->join_table_insert_statement($virtual_column);
    for my $virtual_id (@$virtual_ids) {
      $st->execute($id, $virtual_id) or
        die("Couldn't insert : $id, $virtual_id into " .
              $self->join_table_name($virtual_column) . " with " .
                $self->join_table_insert_sql($virtual_column) . ": $!\n");
    }
  }
}

sub insert_statement {
  my $self = shift;
  ($self->{_insert_st} ||= $self->{db}->prepare($self->insert_sql()))
    or die "Can't prepare: " . $self->insert_sql() . ": $!\n";
}

sub insert_sql {
  my $self = shift;
  my $table = $self->table_name();
  my @columns = grep(!$_->virtual_column(), @{$self->{_real_fields}});
  my $column_list = join(", ", map($_->sql_ref_name(), @columns));
  my $placeholder_list = join(", ", map($_->sql_ref_placeholder(), @columns));
  <<INSERT_SQL
INSERT INTO $table ($column_list) VALUES ($placeholder_list)
INSERT_SQL
}

sub join_table_name {
  my ($self, $virtual_column) = @_;
  $self->table()->join_table_name($virtual_column)
}

sub join_table_insert_sql {
  my ($self, $virtual_column) = @_;
  my $join_table_name = $self->join_table_name($virtual_column);
  my $table = $self->table_name();
  my $column = $virtual_column->name();
  <<INSERT_SQL
INSERT INTO $join_table_name (${table}_id, ${column}_id) VALUES (?, ?)
INSERT_SQL
}

sub join_table_insert_statement {
  my ($self, $virtual_column) = @_;
  my $column_name = $virtual_column->name();
  $self->{join_insert}{$column_name} ||=
    $self->{db}->prepare($self->join_table_insert_sql($virtual_column))
      or die "Can't prepare: " . $self->join_table_insert_sql($virtual_column) .
        ": $!\n"
}

1
