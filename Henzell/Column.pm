package Henzell::Column;

use strict;
use warnings;

use Henzell::Crawl;
use Henzell::LookupTable;

my %SQL_NAME_MAP = Henzell::Crawl::config_hash('sql-field-names');

my %TYPEMAP = ('' => 'CITEXT',
               'S' => 'TEXT',
               'PK' => 'SERIAL',
               'I' => 'INT',
               'REF' => 'INT',
               'IB' => 'BIGINT',
               'ET' => 'BIGINT',
               'IH' => 'NUMERIC(18)',
               'D' => 'TIMESTAMP',
               '!' => 'BOOLEAN');

my %DEFMAP = ('I' => 'DEFAULT 0',
              'ET' => 'DEFAULT 0',
              'IB' => 'DEFAULT 0',
              'IH' => 'DEFAULT 0');

my %COLS;
sub decorated_column_by_name {
  my $name = shift;
  if (!%COLS) {
    for my $table (Henzell::Crawl::config_list('query-tables')) {
      for my $field (Henzell::Crawl::config_list("$table-fields-with-type")) {
        (my $name = $field) =~ s/[A-Z]*\W*$//;
        $COLS{$name} = $field;
      }
    }
  }
  $COLS{$name}
}


my %cached_lookup_tables;
sub lookup_table_for_column {
  my ($column) = @_;
  $cached_lookup_tables{$column->name()} ||=
    _create_lookup_table_for_column($column)
}

sub _create_lookup_table_for_column {
  my ($column) = @_;
  return undef unless $column->foreign_key();

  my %lookups = Henzell::Crawl::config_hash('lookup-tables');
  my $column_name = $column->name();
  for my $lookup_table (keys %lookups) {
    my $fields = $lookups{$lookup_table};
    my $generated_fields = [];
    if (ref($fields) eq 'HASH') {
      $generated_fields =
        [map(Henzell::Column->new($_), @{$$fields{'generated-fields'} || []})];
      $fields = $$fields{fields};
    }
    if (grep($_ eq $column_name, @$fields)) {
      my $columns = [map(Henzell::Column->by_name($_), @$fields)];
      return Henzell::LookupTable->new(name => $lookup_table,
                                       fields => $columns,
                                       generated_fields => $generated_fields);
    }
  }

  Henzell::LookupTable->new(name => $column->name(),
                            fields => [$column])
}


sub by_name {
  my ($cls, $column) = @_;
  $cls->new(decorated_column_by_name($column))
}

sub new {
  my ($cls, $column) = @_;
  my $self = bless { _column => $column }, $cls;
  $self->{date} = $self->type() eq 'D';
  $self->{boolean} = $self->boolean();
  $self->{numeric} = $self->numeric();
  $self
}

sub name {
  my $self = shift;
  if (!$self->{_name}) {
    ($self->{_name} = $self->{_column}) =~ s/[A-Z]*\W*$//;
  }
  $self->{_name}
}

sub sql_boolean_value {
  my ($self, $value) = @_;
  no warnings qw/uninitialized/;
  $value eq 'y' ? 't' : 'f'
}

sub sql_numeric_value {
  my ($self, $value) = @_;
  $value || 0
}

sub sql_value {
  my ($self, $value) = @_;
  return $self->sql_boolean_value($value) if $self->{boolean};
  return $self->sql_numeric_value($value) if $self->{numeric};
  $value || ''
}

sub sql_ref_placeholder {
  my $self = shift;
  $self->{date} ? "TO_TIMESTAMP(?, 'YYYYMMDDHH24MISS')" : "?"
}

sub sql_ref_name {
  my $self = shift;
  my $sql_name = $self->sql_name();
  $self->foreign_key() ? $sql_name . "_id" : $sql_name
}

sub sql_ref_type {
  my $self = shift;
  $self->foreign_key() ? $TYPEMAP{REF} : $self->sql_type()
}

sub sql_ref_default {
  my $self = shift;
  $self->foreign_key() ? '' : ((!$self->primary_key() &&
                                $DEFMAP{$self->type()}) || '')
}

sub lookup_table {
  my $self = shift;
  $self->{_lookup_table} ||= lookup_table_for_column($self)
}

sub lookup_table_name {
  my $self = shift;
  if ($self->foreign_key()) {
    return $self->lookup_table()->name();
  }
  return undef;
}

sub primary_key_constraint {
  my $self = shift;
  "PRIMARY KEY (" . $self->sql_name() . ")"
}

sub foreign_key_constraint {
  my $self = shift;
  "FOREIGN KEY (" . $self->sql_ref_name() . ") REFERENCES " .
    $self->lookup_table_name() . " (id)"
}

sub sql_name {
  my $self = shift;
  my $name = $self->name();
  $SQL_NAME_MAP{$name} || $name
}

sub type {
  my $self = shift;
  if (!defined($self->{_type})) {
    my ($type) = $self->{_column} =~ /([A-Z]+)/;
    $type = '!' if $self->boolean();
    $self->{_type} = $type || '';
  }
  $self->{_type}
}

sub sql_type {
  my $self = shift;
  return $TYPEMAP{PK} if $self->primary_key();
  $TYPEMAP{$self->type()}
}

sub has_qualifier {
  my ($self, $qual) = @_;
  $self->{_column} =~ /\Q$qual/
}

sub indexed {
  my $self = shift;
  $self->has_qualifier('?')
}

sub non_summarisable {
  my $self = shift;
  $self->has_qualifier('*')
}

sub case_sensitive {
  my $self = shift;
  $self->type() eq 'S'
}

sub date {
  my $self = shift;
  $self->{date}
}

sub numeric {
  my $self = shift;
  index($self->type(), 'I') == 0 || index($self->type(), 'ET') == 0
}

sub primary_key {
  my $self = shift;
  $self->has_qualifier('%')
}

sub foreign_key {
  my $self = shift;
  $self->has_qualifier('^')
}

sub boolean {
  my $self = shift;
  $self->has_qualifier('!')
}

1
