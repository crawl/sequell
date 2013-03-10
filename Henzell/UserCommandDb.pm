package Henzell::UserCommandDb;

use strict;
use warnings;
use DBI;

my $user_command_file = 'dat/user_commands.db';

sub db_file {
  $user_command_file
}

sub user_commands {
  return () unless -f $user_command_file;
  my $db = DBI->connect("dbi:SQLite:dbname=$user_command_file", "", "");
  my $st = $db->prepare('SELECT name, definition FROM user_commands');
  $st->execute;

  my %cmd;
  while (my $row = $st->fetchrow_arrayref) {
    $cmd{$row->[0]} = $row->[1];
  }
  $st->finish;
  %cmd
}

1
