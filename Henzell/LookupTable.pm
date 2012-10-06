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
  print STDERR "[QUERY] Lookup in " . $self->name() . " " . $self->lookup_column()->sql_name() . " = $value\n";
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

  my $describe_insert = sub {
    "insert " . join(", ", @insert_values) . " into " . $self->name()
  };

  print STDERR "[INSERT] " . $describe_insert->() . "\n";
  $st->execute(@insert_values) or
    die("Could not " . $describe_insert->() . ": $!\n");
  $db->last_insert_id(undef, undef, $self->name(), undef)
    or die("Could not determine last insert id for " .
           $describe_insert->() . "\n")
}

sub insert_statement_sql {
  my $self= shift;
  my $table_name = $self->name();
  my @columns = map($_->sql_name(), $self->table_fields());
  my $column_list = join(", ", @columns);
  my $placeholder_list = join(", ", ("?") x @columns);
  my $sql = <<INSERT;
INSERT INTO $table_name ($column_list) VALUES ($placeholder_list)
INSERT
}

sub insert_statement {
  my ($self, $db) = @_;
  $self->{_insert_st} ||= $db->prepare($self->insert_statement_sql())
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
