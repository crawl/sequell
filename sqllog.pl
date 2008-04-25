#!/usr/bin/perl

use strict;
use warnings;
use Fcntl qw/SEEK_SET SEEK_CUR SEEK_END/;
use IO::Handle;

use DBI;

my @LOGFIELDS_DECORATED = qw/v lv scI name uidI race cls char xlI sk
  sklevI title ktyp killer kaux place br lvlI ltyp hpI mhpI mmhpI damI
  strI intI dexI god pietyI penI wizI start end durI turnI uruneI
  nruneI tmsg vmsg/;

my @LOGFIELDS = map { my $x = $_; $x =~ s/I$//; $x } @LOGFIELDS_DECORATED;

my $LOGFILE = "$ENV{HOME}/fun/crawl/crawl-ref/source/saves/logfile";
my $DBFILE = "$ENV{HOME}/logfile.db";

my $dbh = open_db();
my $insert_st = prepare_insert_st($dbh);

sub launch {
  system "renice +10 $$ &>/dev/null";
  open my $loghandle, '<', $LOGFILE or die "Can't read $LOGFILE: $!\n";
  binmode $loghandle;
  unless (cat_logfile($loghandle)) {
    cat_logfile($loghandle, -1);
  }
  cleanup_db();
}

sub open_db {
  my $dbsize = -s $DBFILE;
  my $dbh = DBI->connect("dbi:SQLite:$DBFILE");
  create_tables($dbh) if !defined($dbsize) || $dbsize == 0;
  return $dbh;
}

sub cleanup_db {
  undef $insert_st;
  $dbh->disconnect();
}

sub prepare_insert_st {
  my $dbh = shift;
  my $text = "INSERT INTO logrecord ("
    . join(', ', 'offset', @LOGFIELDS)
    . ") VALUES ("
    . join(', ', map("?", 'offset', @LOGFIELDS))
    . ")";
  my $st = $dbh->prepare($text) or die "Can't prepare $text: $!\n";
  return $st;
}

sub create_tables {
  my $dbh = shift;
  my $table_ddl = <<TABLEDDL;
CREATE TABLE logrecord (
    offset INTEGER UNIQUE PRIMARY KEY,
    v STRING,
    lv STRING,
    sc INTEGER,
    name STRING,
    uid STRING,
    race STRING,
    cls STRING,
    char STRING,
    xl INT,
    sk STRING,
    sklev INT,
    title STRING,
    ktyp STRING,
    killer STRING,
    kaux STRING,
    place STRING,
    br STRING,
    lvl INTEGER,
    ltyp STRING,
    hp INTEGER,
    mhp INTEGER,
    mmhp INTEGER,
    dam INTEGER,
    str INTEGER,
    int INTEGER,
    dex INTEGER,
    god STRING,
    piety INTEGER,
    pen INTEGER,
    wiz INTEGER,
    start STRING,
    end STRING,
    dur INTEGER,
    turn INTEGER,
    urune INTEGER,
    nrune INTEGER,
    tmsg STRING,
    vmsg STRING
);
TABLEDDL

  $dbh->do( $table_ddl ) or die "Can't create table schema!: $!\n";
  for my $indexddl ("CREATE INDEX inames ON logrecord (name);",
                    "CREATE INDEX ioffsets ON logrecord (offset);",
                    "CREATE INDEX iscores ON logrecord (sc);",
                    "CREATE INDEX ichar ON logrecord (char);") {
    $dbh->do($indexddl) or die "Can't create $indexddl: $!\n";
  }
}

sub find_start_offset {
  my $st = "SELECT MAX(offset) FROM logrecord";
  my $aref = $dbh->selectall_arrayref($st);
  my $rowoffset = $aref->[0]->[0] || -1;
  return $rowoffset;
}

sub truncate_logrecord_table {
  $dbh->do("DELETE FROM logrecord") or die "Can't truncate logrecord: $!\n";
}

sub go_to_offset {
  my ($loghandle, $offset) = @_;
  if ($offset == -1) {
    seek($loghandle, 0, SEEK_SET);
    truncate_logrecord_table();
    return;
  }

  if ($offset > 0) {
    # Seek to the newline.
    seek($loghandle, $offset - 1, SEEK_SET)
      or die "Failed to seek to @{ [ $offset - 1 ] }\n";

    my $nl;
    die "No NL where expected: '$nl'"
      unless read($loghandle, $nl, 1) == 1 && $nl eq "\n";
  }
  else {
    seek($loghandle, $offset, SEEK_SET) or die "Failed to seek to $offset\n";
  }
  my $lastline = <$loghandle>;
  $lastline =~ /\n$/
    or die "Last line allegedly read ($lastline) not newline terminated.";
  return 1;
}

sub cat_logfile {
  my ($loghandle, $offset) = @_;
  $offset = find_start_offset() unless defined $offset;

  eval {
    go_to_offset($loghandle, $offset);
  };
  print "$@\n" if $@;
  return if $@;

  my $linestart;
  my $rows = 0;
  $dbh->begin_work;
  while (1) {
    $linestart = tell($loghandle);
    my $line = <$loghandle>;
    last unless $line && $line =~ /\n$/;
    ++$rows;
    add_logline($linestart, $line);
    if (!($rows % 2000)) {
      $dbh->commit;
      $dbh->begin_work;
      print "Committed $rows rows.\r";
      STDOUT->flush;
    }
  }
  $dbh->commit;
  seek($loghandle, $linestart, SEEK_SET);
  print "Updated db with $rows records.\n" if $rows;
  return 1;
}

sub logfield_hash {
  my $line = shift;
  chomp $line;
  $line =~ s/::/\n/g;
  my @fields = split(/:/, $line);
  my %fieldh;
  for my $field (@fields) {
    s/\n/:/g for $field;
    my ($key, $val) = $field =~ /^(\w+)=(.*)/;
    next unless defined $key;
    $fieldh{$key} = $val;
  }
  return \%fieldh;
}

sub add_logline {
  my ($offset, $line) = @_;
  chomp $line;
  my $fields = logfield_hash($line);
  my @bindvalues = ($offset,
    map {
      my $integer = /I$/;
      (my $key = $_) =~ s/I$//;
      my $val = $$fields{$key};
      $val = $integer? 0 : '' unless defined $val;
      $val
    } @LOGFIELDS_DECORATED);
  $insert_st->execute(@bindvalues) or die "Can't insert record for $line: $!\n";
}

1;
