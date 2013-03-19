package Henzell::Schema;

use strict;
use warnings;

use lib '..';
use Henzell::Crawl;
use Henzell::Table;

sub statements {
  join("\n", map("$_;", grep($_, @_)))
}

sub new {
  my ($self, %options) = @_;
  bless { %options }, $self
}

sub _load {
  my $self = shift;
  return if $self->{_loaded};
  $self->{_game_types} = { Henzell::Crawl::config_hash('game-type-prefixes') };
  $self->{_query_tables} = [ Henzell::Crawl::config_list('query-tables') ];
  $self->{_loaded} = 1;
}

sub sql {
  my $self = shift;
  if (!$self->{indexes_only}) {
    join("\n\n",
         $self->cleanup_sql(),
         $self->table_ddl(),
         $self->canary_ddl())
  } else {
    join("\n\n", $self->index_ddl());
  }
}

sub list_tables {
  my ($self, $action) = @_;
  map {
    my $type = $self->{_game_types}{$_};
    map($action->("$type$_", $_), @{$self->{_query_tables}})
  } (sort keys %{$self->{_game_types}});
}

sub _find_tables {
  my $self = shift;
  map {
    my $type = $self->{_game_types}{$_};
    map("$type$_", @{$self->{_query_tables}})
  } (sort keys %{$self->{_game_types}});
}

sub base_tables {
  my $self = shift;
  $self->_load();
  @{$self->{_query_tables}}
}

sub tables {
  my $self = shift;
  $self->_load();
  $self->list_tables(sub {
                       my ($fullname, $basename) = @_;
                       Henzell::Table->new($fullname, $basename)
                     })
}

sub table_names {
  my $self = shift;
  $self->_load();
  @{$self->{_tables} ||= [$self->_find_tables()]}
}

sub join_table_names {
  my $self = shift;
  map($_->join_table_names(), $self->tables())
}

sub lookup_tables_for {
  my ($self, $table) = @_;
  @{ $self->{"_lookup_tables_$table"} ||=
     [ Henzell::Table->new($table, $table)->lookup_tables() ] }
}

sub lookup_tables {
  my $self = shift;
  if (!$self->{_lookup_tables}) {
    my @lookup_tables = map($self->lookup_tables_for($_), $self->base_tables());
    my %dedupe;
    @lookup_tables = sort {
      $a->name() cmp $b->name()
    } grep(!$dedupe{$_->name()}++, @lookup_tables);
    $self->{_lookup_tables} = \@lookup_tables;
  }
  @{$self->{_lookup_tables}}
}

sub all_tables {
  my $self = shift;
  ($self->join_table_names(), $self->table_names(),
   map($_->name(), $self->lookup_tables()))
}

sub cleanup_sql {
  my $self = shift;
  statements(map("DROP TABLE IF EXISTS $_", $self->all_tables()))
}

sub each_table_statements {
  my ($self, $action) = @_;
  statements(grep($_, map {
    my $type = $self->{_game_types}{$_};
    map($action->("$type$_", $_), @{$self->{_query_tables}})
  } (sort keys %{$self->{_game_types}})))
}

sub table_ddl {
  my $self = shift;

  statements(
    map($_->ddl(), $self->lookup_tables()),
    $self->each_table_statements(
      sub {
        my ($table, $base_name) = @_;
        $self->table_def($table, $base_name)
      }))
}

sub index_ddl {
  my $self = shift;
  $self->lookup_tables();
  statements(
    $self->each_table_statements(
      sub {
        my ($table, $base_name) = @_;
        $self->table_def($table, $base_name)
      }))
}

sub table {
  my ($self, $table, $base) = @_;
  $self->{"_$table"} ||= Henzell::Table->new($table, $base)
}

sub table_def {
  my ($self, $table_name, $base) = @_;

  my $table = $self->table($table_name, $base);
  $table->sql(tables_only => $self->{tables_only},
              indexes_only => $self->{indexes_only})
}

sub canary_ddl {
  <<CANARY
DROP TABLE IF EXISTS canary;
CREATE TABLE canary (last_update TIMESTAMP);
CANARY
}

1
