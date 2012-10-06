package Henzell::LookupTable;

use strict;
use warnings;

use Henzell::Crawl;

my %COMPUTED_FIELDS = (
  vnum => sub {
    my $value = shift;
    Henzell::Crawl::version_numberize($value)
  });

sub new {
  my ($cls, %props) = @_;
  $props{generated_fields} ||= [];
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

sub generated_fields {
  my $self = shift;
  @{$self->{generated_fields}}
}

sub lookup_column {
  my $self = shift;
  ($self->fields())[0]
}

sub table_fields {
  my $self = shift;
  ($self->lookup_column(), $self->generated_fields())
}

sub column_def {
  my ($self, $field) = @_;
  $field->sql_name() . " " . $field->sql_type() . " UNIQUE"
}

sub column_defs {
  my $self = shift;
  ("id SERIAL UNIQUE",
   map($self->column_def($_), $self->table_fields()))
}

sub lookup_value_id {
  my ($self, $db, $value) = @_;

  # Does the value already exist in the db?
  my $value_id = $self->query_value_id($db, $value);
  return $value_id if $value_id;
  $self->insert_value_id($db, $value)
}

sub query_value_id {
  my ($self, $db, $value) = @_;
  my $st = $self->query_statement($db);
  $st->execute($value);
  my $row = $st->fetchrow_arrayref;
  $row && $row->[0]
}

sub compute_field {
  my ($self, $computed_field, $value) = @_;
  $COMPUTED_FIELDS{$computed_field->name()}($value)
}

sub insert_value_id {
  my ($self, $db, $value) = @_;
  my @insert_values = ($value);
  for my $computed_field ($self->generated_fields()) {
    push @insert_values, $self->compute_field($computed_field, $value);
  }
  my $st = $self->insert_statement($db);
  $st->execute(@insert_values) or
    die("Could not insert " . join(", ", @insert_values) . " into " .
        $self->name() . ": $!\n");
  $db->last_insert_id()
}

sub insert_statement {
  my ($self, $db) = @_;
  if (!$self->{_insert_st}) {
    my $table_name = $self->name();
    my @columns = map($_->sql_name(), $self->table_fields());
    my $column_list = join(", ", @columns);
    my $placeholder_list = join(", ", ("?") x @columns);
    my $sql = <<INSERT;
INSERT INTO $table_name ($column_list) VALUES ($placeholder_list)
INSERT
  }
}

sub query_statement {
  my ($self, $db) = @_;

  if (!$self->{_query_st}) {
    my $table_name = $self->name();
    my $column_name = $self->lookup_column()->sql_name();

    my $sql = <<QUERY;
SELECT id FROM $table_name WHERE $column_name = ?
QUERY
    $self->{_query_st} = $db->prepare($sql) or die "Could not prepare: $sql\n";
  }
  $self->{_query_st}
}

1
