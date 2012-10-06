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
  my $self = shift;
  bless { }, $self
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
  join("\n\n",
       $self->cleanup_sql(),
       $self->table_ddl(),
       $self->canary_ddl())
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
  @{$self->{_tables} ||= [$self->_find_tables()]}
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
  ($self->tables(), map($_->name(), $self->lookup_tables()))
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

  statements(map($_->ddl(), $self->lookup_tables()),
             $self->each_table_statements(sub {
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
  $table->sql()
}

sub canary_ddl {
  ''
}

1
