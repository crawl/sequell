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

my $LOGFILE = "allgames.txt";
my $DBFILE = "$ENV{HOME}/logfile.db";

my $dbh = open_db();
my $insert_st = prepare_insert_st($dbh);
my $offset_st = prepare_offset_st($dbh);

sub launch {
  system "renice +10 $$ &>/dev/null";
  open my $loghandle, '<', $LOGFILE or die "Can't read $LOGFILE: $!\n";
  binmode $loghandle;
  unless (cat_logfile($LOGFILE, $loghandle)) {
    cat_logfile($LOGFILE, $loghandle, -1);
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
  undef $offset_st;
  $dbh->disconnect();
}

sub prepare_st {
  my ($dbh, $query) = @_;
  my $st = $dbh->prepare($query) or die "Can't prepare $query: $!\n";
  return $st;
}

sub prepare_insert_st {
  my $dbh = shift;
  my @allfields = ('file', 'offset', @LOGFIELDS);
  my $text = "INSERT INTO logrecord ("
    . join(', ', @allfields)
    . ") VALUES ("
    . join(', ', map("?", @allfields))
    . ")";
  return prepare_st($dbh, $text);
}

sub prepare_offset_st {
  my $dbh = shift;
  return prepare_st($dbh,
                    "SELECT MAX(offset) FROM logrecord WHERE file = ?");
}

sub create_tables {
  my $dbh = shift;
  my $table_ddl = <<TABLEDDL;
CREATE TABLE logrecord (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file TEXT,
    offset INTEGER,
    v TEXT,
    lv TEXT,
    sc INTEGER,
    name TEXT,
    uid TEXT,
    race TEXT,
    cls TEXT,
    char TEXT,
    xl INT,
    sk TEXT,
    sklev INT,
    title TEXT,
    ktyp TEXT,
    killer TEXT,
    kaux TEXT,
    place TEXT,
    br TEXT,
    lvl INTEGER,
    ltyp TEXT,
    hp INTEGER,
    mhp INTEGER,
    mmhp INTEGER,
    dam INTEGER,
    str INTEGER,
    int INTEGER,
    dex INTEGER,
    god TEXT,
    piety INTEGER,
    pen INTEGER,
    wiz INTEGER,
    start TEXT,
    end TEXT,
    dur INTEGER,
    turn INTEGER,
    urune INTEGER,
    nrune INTEGER,
    tmsg TEXT,
    vmsg TEXT
);
TABLEDDL

  $dbh->do( $table_ddl ) or die "Can't create table schema!: $!\n";
  for my $indexddl (
                    "CREATE INDEX inames ON logrecord (name);",
                    "CREATE INDEX ioffsets ON logrecord (offset);",
                    "CREATE INDEX iscores ON logrecord (sc);",
                    "CREATE INDEX ichar ON logrecord (char);",
                    "CREATE INDEX igod ON logrecord (god);",
                    "CREATE INDEX iplace ON logrecord (place);",
                    "CREATE INDEX irace ON logrecord (race);",
                    "CREATE INDEX icls ON logrecord (cls);",
                    "CREATE INDEX isk ON logrecord (sk);",
                    "CREATE INDEX iend ON logrecord (end);",
                    "CREATE INDEX istart ON logrecord (start);",
                    "CREATE INDEX iver ON logrecord (v);",
                    "CREATE INDEX iktyp ON logrecord (ktyp);",
                   )
  {
    $dbh->do($indexddl) or die "Can't create $indexddl: $!\n";
  }
}

sub find_start_offset {
  my $file = shift;
  $offset_st->execute($file);
  my $rows = $offset_st->fetchall_arrayref;
  return $rows->[0]->[0] || 0 if $rows && $rows->[0];
  return 0;
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
  my ($lfile, $loghandle, $offset) = @_;
  $offset = find_start_offset($lfile) unless defined $offset;
  die "No offset into $lfile" unless defined $offset;

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
    add_logline($lfile, $linestart, $line);
    if (!($rows % 2000)) {
      $dbh->commit;
      $dbh->begin_work;
      print "Committed $rows rows from $lfile.\r";
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
  my ($file, $offset, $line) = @_;
  chomp $line;
  my $fields = logfield_hash($line);
  my @bindvalues = ($file, $offset,
    map {
      my $integer = /I$/;
      (my $key = $_) =~ s/I$//;
      my $val = $$fields{$key};
      $val = $integer? 0 : '' unless defined $val;
      $val
    } @LOGFIELDS_DECORATED);
  while (1) {
    my $res = $insert_st->execute(@bindvalues);
    my $reason = $!;
    last if $res;
    # If SQLite wants us to retry, sleep one second and take another stab at it.
    die "Can't insert record for $line: $!\n" unless $reason =~ /temporarily unavail/i;
    sleep 1;
  }
}

1;
