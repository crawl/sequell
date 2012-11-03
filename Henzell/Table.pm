package Henzell::Table;

use strict;
use warnings;

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

sub lookup_tables {
  my $self = shift;
  @{ $self->{_lookup_tables} ||= [$self->_find_lookup_tables()] }
};

sub _find_lookup_tables {
  my $self = shift;
  grep($_, map($_->lookup_table(), $self->fieldset()->columns()))
}

sub column_defs {
  my $self = shift;
  map {
    $_->sql_ref_name() . ' ' . $_->sql_ref_type() . ' ' . $_->sql_ref_default()
  } $self->fieldset()->columns()
}

sub constraints {
  my $self = shift;
  my $pk_column = $self->fieldset()->primary_key();
  ($pk_column->primary_key_constraint(),
   map($_->foreign_key_constraint(),
       grep($_->foreign_key(),
            $self->fieldset()->columns())))
}

sub sql {
  my $self = shift;

  my @statements = ($self->table_def(),
                    $self->index_defs());
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

sub index {
  my ($self, @fields) = @_;
  my @sql_fields = map($_->sql_ref_name(), @fields);
  my $name = $self->name();
  my $index_name = "ind_${name}_" . join("_", @sql_fields);
  "CREATE INDEX $index_name ON $name (" . join(", ", @sql_fields) . ")"
}

sub indexes {
  my ($self, $field) = @_;
  return $self->index($field) unless $field->date();
  my $sql_field = $field->sql_ref_name();
  my $name = $self->name();

  my @expr = $sql_field;
  my %functions = Henzell::Crawl::config_hash('value-functions');
  for my $fname (keys(%functions)) {
    my $fdef = $functions{$fname};
    if ($$fdef{type} eq 'D') {
      push @expr, sprintf($$fdef{expr}, $sql_field);
    }
  }

  my @indexes;
  for my $expr (@expr) {
    (my $ind_suffix = $expr) =~ tr/a-zA-Z/_/cd;
    my $index_name = "ind_${name}_${ind_suffix}";
    push @indexes, "CREATE INDEX $index_name ON $name ($expr)"
  }
  @indexes
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
              $self->fieldset()->columns())));
  join(";\n", @indexes)
}

1
