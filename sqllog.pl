#!/usr/bin/perl

use strict;
use warnings;
use Fcntl qw/SEEK_SET SEEK_CUR SEEK_END/;
use IO::Handle;

use DBI;

do 'game_parser.pl';

my @LOGFIELDS_DECORATED = qw/v cv lv scI name uidI race crace cls char
  xlI sk sklevI title ktyp killer ckiller kmod kaux ckaux place br lvlI
  ltyp hpI mhpI mmhpI damI strI intI dexI god pietyI penI wizI start
  end durI turnI uruneI nruneI tmsg vmsg splat/;

my %LOG2SQL = ( name => 'pname',
                char => 'charabbrev',
                str => 'sstr',
                dex => 'sdex',
                int => 'sint',
                start => 'tstart',
                end => 'tend' );

my %SERVER_MAP = (cao => 'crawl.akrasiac.org',
                  cdo => 'crawl.develz.org');

my @LOGFIELDS = map { my $x = $_; $x =~ s/I$//; $x } @LOGFIELDS_DECORATED;

my @INSERTFIELDS = ('file', 'src', 'offset', @LOGFIELDS);
my @SELECTFIELDS = ('id', @INSERTFIELDS);

my @INDEX_COLS = qw/src file v cv sc name race crace cls char xl
ktyp killer ckiller kmod kaux ckaux place str int dex god
start end dur turn urune nrune splat dam/;

for (@LOGFIELDS, @INDEX_COLS, @SELECTFIELDS) {
  $LOG2SQL{$_} = $_ unless exists $LOG2SQL{$_};
}

my @INDEX_CASES = ( '' );

my @UNIQUES = ("Ijyb", "Blork the orc", "Urug", "Erolcha", "Snorg",
  "Polyphemus", "Adolf", "Antaeus", "Xtahua", "Tiamat", "Boris",
  "Murray", "Terence", "Jessica", "Sigmund", "Edmund", "Psyche",
  "Donald", "Michael", "Joseph", "Erica", "Josephine", "Harold",
  "Norbert", "Jozef", "Agnes", "Maud", "Louise", "Francis", "Frances",
  "Rupert", "Wayne", "Duane", "Norris", "Frederick", "Margery",
  "Mnoleg", "Lom Lobon", "Cerebov", "Gloorx Vloq", "Geryon",
  "Dispater", "Asmodeus", "Ereshkigal");

my %UNIQUES = map(($_ => 1), @UNIQUES);

my $LOGFILE = "allgames.txt";
my $COMMIT_INTERVAL = 3000;

my $SPLAT_TS = 'splat.timestamp';
my $SPLAT_REPO = '../c-splat.git';
my $SPLAT_CO = '../csplatco';

# Dump indexes if we need to add more than around 9000 lines of data.
my $INDEX_DISCARD_THRESHOLD = 300 * 9000;

my $need_indexes = 1;

my $standalone = not caller();

my $dbh;
my $insert_st;
my $update_st;
my $offset_st;

initialize_sqllog();

sub initialize_sqllog {
  setup_db();
  load_splat_defs();
  load_splat();
}

sub last_splat_time {
  open my $inf, '<', $SPLAT_TS or return;
  chomp(my $ts = <$inf>);
  close $inf;
  $ts
}

sub current_splat_time {
  if (!-d $SPLAT_CO) {
    system("git clone $SPLAT_REPO $SPLAT_CO")
      and die "Couldn't clone $SPLAT_CO from $SPLAT_REPO\n";
  }
  system("cd $SPLAT_CO && git pull") and die "Couldn't update $SPLAT_REPO\n";

  (stat "$SPLAT_CO/CSplat/Select.pm")[9]
}

sub load_splat_defs {
  if (-d $SPLAT_CO) {
    push @INC, $SPLAT_CO;
    print "Loading $SPLAT_CO/CSplat/Select.pm\n";
    $ENV{SPLAT_HOME} = $SPLAT_CO;
    do "$SPLAT_CO/CSplat/Select.pm";
  }
}

sub load_splat {
  my $splat_time = last_splat_time();
  my $now_splat_time = current_splat_time();
  # Disabled for the nonce
  if ($standalone && (!$splat_time || $splat_time < $now_splat_time)) {
    load_splat_defs();
    update_log_rows();

    open my $outf, '>', $SPLAT_TS or die "Can't write $SPLAT_TS: $!\n";
    print $outf "$now_splat_time\n";
    close $outf;
  }
}

sub setup_db {
  $dbh = open_db();
  $insert_st = prepare_insert_st($dbh);
  $update_st = prepare_update_st($dbh);
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

sub new_db_handle {
  DBI->connect("dbi:mysql:henzell", 'henzell', '')
}

sub open_db {
  my $dbh = new_db_handle();
  check_indexes($dbh);
  return $dbh;
}

sub check_indexes {
  my $dbh = shift;
  $need_indexes = 1;
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
  my @allfields = @INSERTFIELDS;
  my $text = "INSERT INTO logrecord ("
    . join(', ', map($LOG2SQL{$_} || $_, @allfields))
    . ") VALUES ("
    . join(', ', map("?", @allfields))
    . ")";
  return prepare_st($dbh, $text);
}

sub prepare_update_st {
  my $dbh = shift;
  my $text = <<QUERY;
    UPDATE logrecord
    SET @{ [ join(",", map("$LOG2SQL{$_} = ?", @LOGFIELDS)) ] }
    WHERE id = ?
QUERY
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

sub index_cols {
  my @cols = ();
  for my $case (@INDEX_CASES) {
    my @fields = split /\+/, $case;
    for my $field (@INDEX_COLS) {
      next if grep($_ eq $field, @fields);
      push @cols, [ map($LOG2SQL{$_}, @fields, $field) ];
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
  print "Creating indexes...\n";
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
    my $ddl = ("DROP INDEX " . index_name($cols) . " ON logrecord;");
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
    $val =~ tr/_/ /;
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

sub fixup_logfields {
  my $g = shift;
  ($g->{cv} = $g->{v}) =~ s/^(\d+\.\d+).*/$1/;
  $g->{ckiller} = $g->{killer} || $g->{ktyp} || '';
  for ($g->{ckiller}) {
    s/^an? \w+-headed (hydra.*)$/a $1/;
    s/^.*'s? ghost$/a player ghost/;
    s/^an? \w+ (draconian.*)/a $1/;

    # If it's an actual kill, merge Pan lords.
    if ($g->{killer}) {
      $_ = 'a pandemonium lord' if !/^(?:an?|the) / && !$UNIQUES{$_};
    }
  }

  $g->{kmod} = $g->{killer} || '';
  for ($g->{kmod}) {
    if (/spectral (?!warrior)/) {
      $_ = 'a spectral thing';
    }
    elsif (/shapeshifter/) {
      $_ = 'shapeshifter';
    }
    elsif (!s/.*(zombie|skeleton|simulacrum)$/$1/) {
      $_ = '';
    }
  }

  $g->{ckaux} = $g->{kaux} || '';
  for ($g->{ckaux}) {
    s/\{.*?\}//g;
    s/\(.*?\)//g;
    s/[+-]\d+,?\s*//g;
    s/^Hit by (.*) thrown .*$/$1/;
    s/^Shot with (.*) by .*$/$1/;
    s/\b(?:un)?cursed //;
    s/\s+$//;
    s/  / /g;
  }

  $g->{crace} = $g->{race};
  for ($g->{crace}) {
    s/.*(Draconian)$/$1/;
  }

  for ($g->{start}, $g->{end}) {
    s/^(\d{4})(\d{2})/$1 . sprintf("%02d", $2 + 1)/e;
    s/[SD]$//;
  }

  my $src = $g->{src};
  # Fixup src for interesting_game.
  $g->{src} = "http://$SERVER_MAP{$src}/";
  $g->{splat} = CSplat::Select::interesting_game($g) ? 'y' : '';
  $g->{src} = $src;

  $g
}

sub field_val {
  my ($key, $g) = @_;
  my $integer = $key =~ /I$/;
  $key =~ s/I$//;
  my $val = $g->{$key} || ($integer? 0 : '');
  $val
}

sub add_logline {
  my ($file, $source, $offset, $line) = @_;
  chomp $line;
  my $fields = logfield_hash($line);
  $fields->{src} = $source;
  $fields = fixup_logfields($fields);
  my @bindvalues = ($file, $source, $offset,
                    map(field_val($_, $fields), @LOGFIELDS_DECORATED) );
  execute_st($insert_st, @bindvalues) or
    die "Can't insert record for $line: $!\n";
}

sub xlog_escape {
  my $str = shift;
  $str =~ s/:/::/g;
  $str
}

sub xlog_str {
  my $g = shift;
  join(":", map("$_=" . xlog_escape($g->{$_}), keys %$g))
}

sub update_game {
  my $g = shift;
  my @bindvals = (map(field_val($_, $g), @LOGFIELDS_DECORATED), $g->{id});
  print "Updating game: ", pretty_print($g), "\n";
  execute_st($update_st, @bindvals) or
    die "Can't update record for game: " . pretty_print($g) . "\n";
}

sub game_from_row {
  my $row = shift;
  my %g;
  for my $i (0 .. $#SELECTFIELDS) {
    $g{$SELECTFIELDS[$i]} = $row->[$i];
  }
  \%g
}

sub games_differ {
  my ($a, $b) = @_;
  scalar(
         grep(($a->{$_} || '') ne ($b->{$_} || ''),
              @LOGFIELDS) )
}

sub update_log_rows {
  print "Updating all rows in db to match new fixup\n";
  my $selfields = join(", ", map($LOG2SQL{$_}, @SELECTFIELDS));

  my $ndb = new_db_handle();
  die "Unable to connect to db\n" unless $ndb;
  my $sth = $ndb->prepare("SELECT $selfields FROM logrecord")
    or die "Can't fetch rows\n";
  $sth->execute();
  while (my $row = $sth->fetchrow_arrayref) {
    my $g = game_from_row($row);
    # Copy the game.
    my %cg = %$g;
    my $fixed = fixup_logfields(\%cg);
    if (games_differ($g, $fixed)) {
      update_game($fixed);
    }
  }
  $ndb->disconnect();
}

1;
