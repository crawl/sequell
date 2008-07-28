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

my @INDEX_COLS = qw/src file v sc name race cls char xl
ktyp killer kaux place str int dex god
start end dur turn urune nrune /;

my @INDEX_CASES = ( 'src', '' );

my $LOGFILE = "allgames.txt";
my $DBFILE = "$ENV{HOME}/logfile.db";
my $COMMIT_INTERVAL = 3000;

# Dump indexes if we need to add more than around 600 lines of data.
my $INDEX_DISCARD_THRESHOLD = 300 * 600;

my $need_indexes = 1;

my $dbh;
my $insert_st;
my $offset_st;

setup_db();

sub setup_db {
  $dbh = open_db();
  $insert_st = prepare_insert_st($dbh);
  $offset_st = prepare_offset_st($dbh);
}

sub reopen_db {
  cleanup_db();
  setup_db();
}

sub launch {
  system "renice +10 $$ &>/dev/null";
  open my $loghandle, '<', $LOGFILE or die "Can't read $LOGFILE: $!\n";
  binmode $loghandle;
  unless (cat_logfile($LOGFILE, 'test', $loghandle)) {
    cat_logfile($LOGFILE, 'test', $loghandle, -1);
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
  my @allfields = ('file', 'src', 'offset', @LOGFIELDS);
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

sub sql_register_logfiles {
  my @files = @_;
  $dbh->begin_work;
  $dbh->do("DELETE FROM logfiles;") or die "Couldn't delete file records: $!\n";
  my $insert = "INSERT INTO logfiles VALUES (?);";
  my $st = $dbh->prepare($insert) or die "Can't prepare $insert: $!\n";
  for my $file (@files) {
    execute_st($st, $file) or
      die "Couldn't insert record for $file with $insert: $!\n";
  }
  $dbh->commit;
}

sub create_tables {
  my $dbh = shift;
  my $table_ddl = <<TABLEDDL;
CREATE TABLE logfiles (
    file TEXT PRIMARY KEY
);
TABLEDDL

  $dbh->do( $table_ddl ) or die "Can't create table schema!: $!\n";

  $table_ddl = <<TABLEDDL;
CREATE TABLE logrecord (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file TEXT COLLATE NOCASE,
    src TEXT COLLATE NOCASE,
    offset INTEGER,
    v TEXT COLLATE NOCASE,
    lv TEXT COLLATE NOCASE,
    sc INTEGER,
    name TEXT COLLATE NOCASE,
    uid TEXT COLLATE NOCASE,
    race TEXT COLLATE NOCASE,
    cls TEXT COLLATE NOCASE,
    char TEXT COLLATE NOCASE,
    xl INT,
    sk TEXT COLLATE NOCASE,
    sklev INT,
    title TEXT COLLATE NOCASE,
    ktyp TEXT COLLATE NOCASE,
    killer TEXT COLLATE NOCASE,
    kaux TEXT COLLATE NOCASE,
    place TEXT COLLATE NOCASE,
    br TEXT COLLATE NOCASE,
    lvl INTEGER,
    ltyp TEXT COLLATE NOCASE,
    hp INTEGER,
    mhp INTEGER,
    mmhp INTEGER,
    dam INTEGER,
    str INTEGER,
    int INTEGER,
    dex INTEGER,
    god TEXT COLLATE NOCASE,
    piety INTEGER,
    pen INTEGER,
    wiz INTEGER,
    start TEXT COLLATE NOCASE,
    end TEXT COLLATE NOCASE,
    dur INTEGER,
    turn INTEGER,
    urune INTEGER,
    nrune INTEGER,
    tmsg TEXT COLLATE NOCASE,
    vmsg TEXT COLLATE NOCASE
);
TABLEDDL

  $dbh->do( $table_ddl ) or die "Can't create table schema!: $!\n";
  $dbh->do( 'CREATE INDEX ind_foffset on logrecord (file, offset);' );
  $need_indexes = 1;
}

sub index_cols {
  my @cols = ();
  for my $case (@INDEX_CASES) {
    my @fields = split /\+/, $case;
    for my $field (@INDEX_COLS) {
      next if grep($_ eq $field, @fields);
      push @cols, [ @fields, $field ];
    }
  }
  @cols
}

sub index_name {
  my $cols = shift;
  "ind_" . join("_", @$cols)
}

sub create_indexes {
  my $op = shift;
  print "Creating indexes...";
  for my $cols (index_cols()) {
    my $name = index_name($cols);
    print "Creating index $name...\n";
    my $ddl = ("CREATE INDEX " . index_name($cols) . " ON logrecord (" .
      join(", ", @$cols) . ");");
    $dbh->do($ddl);
  }
  $need_indexes = 0;
  reopen_db();
}

sub drop_indexes {
  print "Dropping all indexes (errors are harmless)...\n";
  for my $cols (index_cols()) {
    my $ddl = ("DROP INDEX " . index_name($cols) . ";");
    $dbh->do($ddl);
  }
  $need_indexes = 1;
  reopen_db();
}

sub fixup_db {
  create_indexes() if $need_indexes;
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
    or die "Last line allegedly read ($lastline) at $offset not newline terminated.";
  return 1;
}

sub cat_logfile {
  my ($lfile, $source, $loghandle, $offset) = @_;
  $offset = find_start_offset($lfile) unless defined $offset;
  die "No offset into $lfile" unless defined $offset;

  my $size = -s($lfile);
  my $outstanding_size = $size - $offset;
  drop_indexes() if $outstanding_size > $INDEX_DISCARD_THRESHOLD;

  eval {
    go_to_offset($loghandle, $offset);
  };
  print "Error seeking in $lfile: $@\n" if $@;
  return if $@;

  my $linestart;
  my $rows = 0;
  $dbh->begin_work;
  while (1) {
    $linestart = tell($loghandle);
    my $line = <$loghandle>;
    last unless $line && $line =~ /\n$/;
    ++$rows;
    add_logline($lfile, $source, $linestart, $line);
    if (!($rows % $COMMIT_INTERVAL)) {
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

sub execute_st {
  my $st = shift;
  while (1) {
    my $res = $st->execute(@_);
    return 1 if $res;
    my $reason = $!;
    # If SQLite wants us to retry, sleep one second and take another stab at it.
    return unless $reason =~ /temporarily unavail/i;
    sleep 1;
  }
}

sub add_logline {
  my ($file, $source, $offset, $line) = @_;
  chomp $line;
  my $fields = logfield_hash($line);
  my @bindvalues = ($file, $source, $offset,
    map {
      my $integer = /I$/;
      (my $key = $_) =~ s/I$//;
      my $val = $$fields{$key};
      $val = $integer? 0 : '' unless defined $val;
      $val
    } @LOGFIELDS_DECORATED);
  execute_st($insert_st, @bindvalues) or
    die "Can't insert record for $line: $!\n";
}

1;
