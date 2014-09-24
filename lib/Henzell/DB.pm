package Henzell::DB;

use strict;
use warnings;

use DBI;
use Henzell::Crawl;

my $DBNAME = $ENV{SEQUELL_DBNAME} || 'sequell';
my $DBUSER = 'sequell';
my $DBPASS = 'sequell';

sub db_url {
  my $dbname = shift;
  "dbi:Pg:dbname=$dbname"
}

sub new_db_handle(;$$$) {
  my ($dbname, $dbuser, $dbpass) = @_;
  $dbname ||= $DBNAME;
  $dbuser ||= $DBUSER;
  $dbpass ||= $DBPASS;
  $DBNAME = $dbname;
  $DBUSER = $dbuser;
  $DBPASS = $dbpass;
  my $url = db_url($dbname);
  print "Connecting to $url as $dbuser\n";
  my $dbh = DBI->connect($url, $dbuser, $dbpass)
    or die "Could not connect to $url as $dbuser: $!\n";
  $dbh
}

sub open_db {
  new_db_handle();
}

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

1
