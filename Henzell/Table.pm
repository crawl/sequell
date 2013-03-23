package Henzell::Table;

use strict;
use warnings;

use lib '..';
use Henzell::Crawl;
use Henzell::FieldSet;

sub new {
  my ($cls, $table, $base) = @_;
  my $self = bless {
    _table => $table,
    _base => $base
  }, $cls;
  $self
}

sub name {
  my $self = shift;
  $self->{_table}
}

sub basename {
  my $self = shift;
  $self->{_base}
}

sub fieldset {
  my $self = shift;
  $self->{"_fieldset"} ||= Henzell::FieldSet->new($self->basename())
}

sub columns {
  shift()->fieldset()->columns()
}

sub lookup_tables {
  my $self = shift;
  @{ $self->{_lookup_tables} ||= [$self->_find_lookup_tables()] }
};

sub _find_lookup_tables {
  my $self = shift;
  grep($_, map($_->lookup_table(), $self->columns()))
}

sub column_defs {
  my $self = shift;
  map {
    $_->sql_ref_name() . ' ' . $_->sql_ref_type() . ' ' . $_->sql_ref_default()
  } (grep(!$_->virtual_column(), $self->columns()))
}

sub constraints {
  my $self = shift;
  my $pk_column = $self->fieldset()->primary_key();
  ($pk_column->primary_key_constraint(),
   map($_->foreign_key_constraint(),
       grep($_->foreign_key(),
            $self->columns())))
}

sub sql {
  my ($self, %opt) = @_;

  my @statements =
    $opt{tables_only} ? ($self->table_def(), $self->join_table_defs()) :
    $opt{indexes_only} ? ($self->index_defs()) :
      ($self->table_def(), $self->join_table_defs(), $self->index_defs());
  join(";\n", @statements)
}

sub table_def {
  my $self = shift;

  my @columndefs = $self->column_defs();
  my @constraints = $self->constraints();
  <<SQL
CREATE TABLE @{[$self->name()]} (
  @{ [ join(",\n  ", @columndefs, @constraints) ]  }
)
SQL
}

sub join_table_names {
  my $self = shift;
  my @join_columns = grep($_->join_table_column(),
                          $self->columns());
  map($self->join_table_name($_), @join_columns)
}

sub join_table_defs {
  my $self = shift;
  my @join_columns = grep($_->join_table_column(),
                          $self->columns());
  my @join_tables = map($self->join_table_sql($_), @join_columns);
  join(";\n", @join_tables)
}

sub join_table_name {
  my ($self, $virtual_column) = @_;
  "j_" . $self->name() . "_" . $virtual_column->name()
}

sub join_table_sql {
  my ($self, $virtual_column) = @_;
  my $name = $self->name();
  my $column_name = $virtual_column->name();
  my $lookup_table = $virtual_column->lookup_table()->name();
  my $table_name = $self->join_table_name($virtual_column);
  <<SQL
CREATE TABLE $table_name (
  ${name}_id INT,
  ${column_name}_id INT,
  FOREIGN KEY (${name}_id) REFERENCES $name (id),
  FOREIGN KEY (${column_name}_id) REFERENCES $lookup_table (id)
);
SQL
}

sub index {
  my ($self, @fields) = @_;
  my @sql_fields = map($_->sql_ref_name(), @fields);
  my $name = $self->name();
  my $index_name = "ind_${name}_" . join("_", @sql_fields);
  "CREATE INDEX $index_name ON $name (" . join(", ", @sql_fields) . ")"
}

sub indexes {
  my ($self, $field) = @_;
  $self->index($field)
}

sub join_table_indexes {
  my ($self, $virtual_column) = @_;
  my $join_table = $self->join_table_name($virtual_column);
  my $self_ref = $self->name() . "_id";
  my $join_ref = $virtual_column->name() . "_id";
  <<INDEXES
CREATE INDEX ind_${join_table}_${self_ref} ON $join_table ($self_ref);
CREATE INDEX ind_${join_table}_${join_ref} ON $join_table ($join_ref)
INDEXES
}

sub join_table_index_defs {
  my $self = shift;
  my @join_cols = grep($_->virtual_column(), $self->columns());
  map($self->join_table_indexes($_), @join_cols)
}

sub index_defs {
  my $self = shift;

  my @compound_index_defs =
    Henzell::Crawl::config_list($self->basename() . "-indexes");
  my @indexes =
    ((map {
      my @field_list = @$_;
      $self->index(map(Henzell::Column->by_name($_), @field_list))
     } @compound_index_defs),
     map($self->indexes($_),
         grep($_->indexed() || $_->foreign_key(),
              $self->columns())));

  push @indexes, $self->join_table_index_defs();
  join(";\n", @indexes)
}

1
