package Henzell::DB;

use strict;
use warnings;

use DBI;
use Henzell::Crawl;

my %GAME_TYPE_PREFIXES = Henzell::Crawl::game_type_prefixes();

sub prepare_st {
  my ($dbh, $query) = @_;
  my $st = $dbh->prepare($query) or die "Can't prepare $query: $!\n";
  return $st;
}

sub exec_query_st {
  my ($dbh, $query) = @_;
  my $st = prepare_st($dbh, $query);
  splice(@_, 0, 2);
  $st->execute(@_) or die "Failed to execute query: $query\n";
  $st
}

sub game_tables {
  my $game_base_table = 'logrecord';
  map("$_$game_base_table", sort(values %GAME_TYPE_PREFIXES))
}

sub milestone_tables {
  my $milestone_base_table = 'milestone';
  map("$_$milestone_base_table", sort(values %GAME_TYPE_PREFIXES))
}

sub compute_version_numbers {
  my $dbh = shift;

  for my $table (game_tables(), milestone_tables()) {
    compute_version_numbers_in_table($dbh, $table);
  }
}

sub compute_version_numbers_in_table {
  my ($dbh, $table) = @_;
  my $query = <<QUERY;
SELECT id, v, cv FROM $table WHERE vnum IS NULL OR cvnum IS NULL
QUERY

  my $st = exec_query_st($dbh, $query);

  my $update_st = $dbh->prepare(<<UPDATE);
UPDATE $table SET vnum = ?, cvnum = ?
WHERE id = ?
UPDATE

  my $commit_interval = 9000;
  my $updates = 0;
  $dbh->begin_work;
  while (my $row = $st->fetchrow_arrayref) {
    update_row_version_numbers($dbh, $table, $update_st,
                               $row->[0], $row->[1], $row->[2]);
    if (!(++$updates % $commit_interval)) {
      $dbh->commit;
      $dbh->begin_work;
      print "\rUpdated version numbers in $updates rows of $table...";
    }
  }
  print "\rUpdated $updates rows of $table.\n";
  $dbh->commit;
}

sub update_row_version_numbers {
  my ($dbh, $table, $update_st, $id, $v, $cv) = @_;
  $update_st->execute(Henzell::Crawl::version_numberize($v),
                      Henzell::Crawl::version_numberize($cv),
                      $id) or die "Could not update row $id in $table: $!";
}

1
