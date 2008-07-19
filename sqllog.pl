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
my $COMMIT_INTERVAL = 15000;

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
    file TEXT COLLATE NOCASE,
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
  for my $indexddl (
                    "CREATE INDEX ind_sc ON logrecord (sc);",
                    "CREATE INDEX ind_name ON logrecord (name);",
                    "CREATE INDEX ind_race ON logrecord (race);",
                    "CREATE INDEX ind_cls ON logrecord (cls);",
                    "CREATE INDEX ind_char ON logrecord (char);",
                    "CREATE INDEX ind_xl ON logrecord (xl);",
                    "CREATE INDEX ind_sk ON logrecord (sk);",
                    "CREATE INDEX ind_sklev ON logrecord (sklev);",
                    "CREATE INDEX ind_title ON logrecord (title);",
                    "CREATE INDEX ind_ktyp ON logrecord (ktyp);",
                    "CREATE INDEX ind_killer ON logrecord (killer);",
                    "CREATE INDEX ind_kaux ON logrecord (kaux);",
                    "CREATE INDEX ind_place ON logrecord (place);",
                    "CREATE INDEX ind_br ON logrecord (br);",
                    "CREATE INDEX ind_lvl ON logrecord (lvl);",
                    "CREATE INDEX ind_ltyp ON logrecord (ltyp);",
                    "CREATE INDEX ind_hp ON logrecord (hp);",
                    "CREATE INDEX ind_mhp ON logrecord (mhp);",
                    "CREATE INDEX ind_mmhp ON logrecord (mmhp);",
                    "CREATE INDEX ind_dam ON logrecord (dam);",
                    "CREATE INDEX ind_str ON logrecord (str);",
                    "CREATE INDEX ind_int ON logrecord (int);",
                    "CREATE INDEX ind_dex ON logrecord (dex);",
                    "CREATE INDEX ind_god ON logrecord (god);",
                    "CREATE INDEX ind_start ON logrecord (start);",
                    "CREATE INDEX ind_end ON logrecord (end);",
                    "CREATE INDEX ind_dur ON logrecord (dur);",
                    "CREATE INDEX ind_turn ON logrecord (turn);",
                    "CREATE INDEX ind_urune ON logrecord (urune);",
                    "CREATE INDEX ind_nrune ON logrecord (nrune);",
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
