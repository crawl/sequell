#!/usr/bin/env perl

use strict;
use warnings;
use Fcntl qw/SEEK_SET SEEK_CUR SEEK_END/;
use IO::Handle;
use DateTime;
use Time::gmtime;

use Henzell::Achieve;
use Henzell::Spork;

use DBI;

do 'game_parser.pl';

my @LOGFIELDS_DECORATED =
  qw/alpha game version cversion points branch levI place placename
     amulet maxlvlI hpI maxhpI
     deathsI deathdateD birthdateD role race gender align gender0 align0
     name deathmsg killer ckiller ktype kstate helpless praying conduct
     nconductI achieve nachieveI turnsI realtimeI starttimeS endtimeS/;

my %LOG2SQL = ( name => 'pname',
                role => 'prole',
                race => 'prace',

                lev  => 'bdepth',

                gender   => 'pgender',
                align    => 'palign',
                gender0 => 'pgender0',
                align0  => 'palign0',

                death => 'deathmsg'
              );

my %SERVER_MAP = (unn => 'un.nethack.nu',
                  spo => 'sporkhack.org',
                  nao  => 'nethack.alt.org');

# Mapping of dnum -> dungeon name in Un; if suffixed with :, they have depths.
my @UNBRANCHES = ('D:', 'Geh:', 'Gnome:', 'Quest:', 'Sok:',
                  'Town', 'Ludios', 'Blackmarket', 'Vlad:',
                  'Plane:', 'Advent');

my @SPORKBRANCHES = ('D:', 'Geh:', 'Gnome:', 'Quest:', 'Sok:',
                     'Ludios', 'Vlad:', 'Plane:');

my %GAME_BRANCHES = (un    => \@UNBRANCHES,
                     spork => \@SPORKBRANCHES);

my @MILESTONE_IDENTIFIER = qw/game_action wish achieve_diff crash shout
                              killed_uniq sokobanprize shoplifted
                              bones_killed killed_shopkeeper/;

my %MILESTONE_PARSER = (game_action => \&milestone_parse_game_action,
                        achieve_diff => \&milestone_parse_achieve,
                        shoplifted => \&milestone_parse_shoplifted,
                        wish => \&milestone_parse_wish,
                        crash => \&milestone_parse_crash,
                        shout => \&milestone_parse_shout,
                        killed_uniq => \&milestone_parse_killed_uniq,
                        killed_shopkeeper => \&milestone_parse_killed_shk,
                        sokobanprize => \&milestone_parse_sokobanprize,
                        bones_killed => \&milestone_parse_bones_killed);

sub strip_suffix($) {
  my $val = shift;
  $val =~ s/[IDS]$//;
  $val
}

my $ORIG_LINE;

my @LOGFIELDS = map(strip_suffix($_), @LOGFIELDS_DECORATED);

my @MILEFIELDS_DECORATED =
    qw/alpha game version cversion branch levI place placename amulet maxlvlI
       hpI maxhpI deathsI birthdateD role race gender align
       gender0 align0 name conduct nconductI achieve nachieveI turnsI realtimeI
       starttimeS currenttimeS mtype mobj mdesc shop shopliftedI
       wish_countI/;

my @INSERTFIELDS = ('file', 'src', 'offset', @LOGFIELDS);

my @MILE_INSERTFIELDS_DECORATED =
  (qw/file src offsetI/, @MILEFIELDS_DECORATED);

my @MILEFIELDS = map(strip_suffix($_), @MILEFIELDS_DECORATED);
my @MILE_INSERTFIELDS = map(strip_suffix($_), @MILE_INSERTFIELDS_DECORATED);

my @SELECTFIELDS = ('id', @INSERTFIELDS);

my @INDEX_COLS =
  qw/src file game version cversion points branch lev place maxlvl hp maxhp
     deaths deathdate birthdate role race gender align gender0 align0
     name deathmsg conduct nconduct achieve nachieve turns realtime starttime
     endtime/;

my @MILE_INDEX_COLS = ('src',
                       grep($_ ne 'milestone', @MILEFIELDS));

my %MILESTONE_VERB =
(
 unique => 'uniq',
 enter => 'br.enter',
 'branch-finale' => 'br.end'
);

for (@LOGFIELDS, @INDEX_COLS, @SELECTFIELDS) {
  $LOG2SQL{$_} = $_ unless exists $LOG2SQL{$_};
}

my @INDEX_CASES = ( '' );

my $TLOGFILE   = 'logrecord';
my $TMILESTONE = 'milestone';

my $COMMIT_INTERVAL = 3000;

# Dump indexes if we need to add more than around 9000 lines of data.
my $INDEX_DISCARD_THRESHOLD = 300 * 9000;

my $need_indexes = 1;

my $standalone = not caller();

my $dbh;
my $insert_st;
my $update_st;
my $milestone_insert_st;

initialize_sqllog();

sub initialize_sqllog {
  setup_db();
}

sub setup_db {
  $dbh = open_db();
  $insert_st = prepare_insert_st($dbh, 'logrecord');
  $milestone_insert_st = prepare_milestone_insert_st($dbh, 'milestone');
  $update_st = prepare_update_st($dbh);
}

sub reopen_db {
  cleanup_db();
  setup_db();
}

sub new_db_handle {
  my $dbh = DBI->connect("dbi:mysql:exxorn", 'exxorn', '');
  $dbh->{mysql_auto_reconnect} = 1;
  $dbh
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
  undef $milestone_insert_st;
  undef $update_st;
  $dbh->disconnect();
}

sub prepare_st {
  my ($dbh, $query) = @_;
  my $st = $dbh->prepare($query) or die "Can't prepare $query: $!\n";
  return $st;
}

sub exec_query_st {
  my $query = shift;
  my $st = prepare_st($dbh, $query);
  $st->execute(@_) or die "Failed to execute query: $query\n";
  $st
}

sub query_one {
  my $st = exec_query_st(@_);
  my $row = $st->fetchrow_arrayref;
  $row && $row->[0]
}

sub query_row {
  my $st = exec_query_st(@_);
  $st->fetchrow_arrayref
}

sub query_all {
  my $st = exec_query_st(@_);
  $st->fetchall_arrayref
}

sub prepare_insert_st {
  my ($dbh, $table) = @_;
  my @allfields = @INSERTFIELDS;
  my $text = "INSERT INTO $table ("
    . join(', ', map($LOG2SQL{$_} || $_, @allfields))
    . ") VALUES ("
    . join(', ', map("?", @allfields))
    . ")";
  return prepare_st($dbh, $text);
}

sub prepare_milestone_insert_st {
  my ($dbh, $table) = @_;
  my @fields = map($LOG2SQL{$_} || $_, @MILE_INSERTFIELDS);
  my $text = "INSERT INTO $table ("
    . join(', ', @fields)
    . ") VALUES ("
    . join(', ', map("?", @fields))
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

sub sql_register_files {
  my ($table, @files) = @_;
  $dbh->begin_work;
  $dbh->do("DELETE FROM $table;") or die "Couldn't delete $table records: $!\n";
  my $insert = "INSERT INTO $table VALUES (?);";
  my $st = $dbh->prepare($insert) or die "Can't prepare $insert: $!\n";
  for my $file (@files) {
    execute_st($st, $file) or
      die "Couldn't insert record into $table for $file with $insert: $!\n";
  }
  $dbh->commit;
}

sub sql_register_logfiles {
  sql_register_files("logfiles", @_)
}

sub sql_register_milestones {
  sql_register_files("milestone_files", @_)
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
  print "Creating indexes on logrecord...\n";
  for my $cols (index_cols()) {
    my $name = index_name($cols);
    print "Creating index $name...\n";
    my $ddl = ("CREATE INDEX " . index_name($cols) . " ON logrecord (" .
      join(", ", @$cols) . ");");
    $dbh->do($ddl);
  }
  $need_indexes = 0;


  for my $rcol (@MILE_INDEX_COLS) {
    my $col = $LOG2SQL{$rcol} || $rcol;
    my $name = "mile_index_$col";
    print "Creating index $name...\n";
    my $ddl = "CREATE INDEX $name ON milestone ($col);";
    $dbh->do($ddl);
  }
  reopen_db();
}

sub fixup_db {
  create_indexes() if $need_indexes;
}

sub find_start_offset_in {
  my ($table, $file) = @_;
  my $query = "SELECT MAX(offset) FROM $table WHERE file = ?";
  my $res = query_one($query, $file);
  defined($res)? $res : -1
}

sub truncate_table {
  my $table = shift;
  $dbh->do("DELETE FROM $table") or die "Can't truncate logrecord: $!\n";
}

sub go_to_offset {
  my ($table, $loghandle, $offset) = @_;

  if ($offset > 0) {
    # Seek to the newline.
    seek($loghandle, $offset - 1, SEEK_SET)
      or die "Failed to seek to @{ [ $offset - 1 ] }\n";

    my $nl;
    die "No NL where expected: '$nl'"
      unless read($loghandle, $nl, 1) == 1 && $nl eq "\n";
  }
  else {
    seek($loghandle, 0, SEEK_SET) or die "Failed to seek to start of file\n";
  }

  if ($offset != -1) {
    my $lastline = <$loghandle>;
    $lastline =~ /\n$/
      or die "Last line allegedly read ($lastline) at $offset not newline terminated.";
  }
  return 1;
}

sub cat_xlog {
  my ($table, $lf, $fadd, $offset) = @_;

  my $loghandle = $lf->{handle};
  my $lfile = $lf->{file};
  $offset = find_start_offset_in($table, $lfile) unless defined $offset;
  die "No offset into $lfile ($table)" unless defined $offset;

  my $size = -s($lfile);
  my $outstanding_size = $size - $offset;

  eval {
    go_to_offset($table, $loghandle, $offset);
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
    # Skip blank lines.
    next unless $line =~ /\S/;
    ++$rows;
    $fadd->($lf, $linestart, $line);
    if (!($rows % $COMMIT_INTERVAL)) {
      $dbh->commit;
      $dbh->begin_work;
      print "Committed $rows rows from $lfile.\r";
      STDOUT->flush;
    }
  }
  $dbh->commit;
  seek($loghandle, $linestart, SEEK_SET);
  print "Updated db with $rows records from $lfile.\n" if $rows;
  return 1;
}

sub cat_logfile {
  my ($lf, $offset) = @_;
  my $table = $TLOGFILE;
  cat_xlog($table, $lf, \&add_logline, $offset)
}

sub cat_stonefile {
  my ($lf, $offset) = @_;
  my $table = $TMILESTONE;
  my $res = cat_xlog($table, $lf, \&add_milestone, $offset);
  print "Linking milestones to completed games ($lf->{server}: $lf->{file})...\n";
  fixup_milestones($lf->{server}) if $res;
  print "Done linking milestones to completed games ($lf->{server}: $lf->{file})...\n";
}

=head2 fixup_milestones()

Attempts to link unlinked milestones with completed games in the logrecord
table. Pretty expensive.

=cut

sub fixup_milestones {
  my ($source, @players) = @_;
  my $prefix = '';
  my $query = <<QUERY;
     UPDATE ${prefix}milestone m
       SET m.game_id = (SELECT l.id FROM ${prefix}logrecord l
                         WHERE l.pname = m.pname
                           AND l.src = m.src
                           AND l.starttime = m.starttime
                         LIMIT 1)
     WHERE m.game_id IS NULL AND m.starttime IS NOT NULL
       AND m.src = ?
QUERY

  if (@players) {
    if (@players == 1) {
      $query .= " AND m.pname = ?";
      exec_query_st($query, $source, $players[0]);
    }
    else {
      @players = map($dbh->quote($_), @players);
      $query .= " AND m.pname IN (";
      $query .= join(", ", @players);
      $query .= ")";
      exec_query_st($query, $source);
    }
  }
  else {
    exec_query_st($query, $source);
  }
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

sub parse_logline($$) {
  my ($line, $sourcefile) = @_;
  my $g;
  if ($sourcefile =~ /wish/ && $sourcefile =~ /spo/) {
    $g = Henzell::Spork::spork_wishtracker_xdict($line);
  } else {
    $g = logfield_hash($line);
  }
  $$g{file} = $sourcefile;
  $g
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

sub xlog_is_milestone($) {
  my $g = shift;
  # No nice uniform way of handling this:
  my $file = $$g{file};
  return $file =~ /wish/ || $file =~ /livelog/;
}

sub default_field_value($$) {
  my ($field, $type) = @_;
  return 0 if $type eq 'I' || $type eq 'S';
  return undef if $type eq 'D';
  return '';
}

sub resolve_branch_name($$) {
  my ($game, $branchid) = @_;
  my $resolved = $GAME_BRANCHES{$game}[$branchid];
  die "Could not resolve branch id $branchid for $game\n"
    unless defined $resolved;
  $resolved
}

sub game_from_filename($) {
  my $filename = shift;
  return 'spork' if $filename =~ /spo/i;
  return 'un' if $filename =~ /un/i;
  return 'nh';
}

sub utc_epoch_seconds_to_fulltime($) {
  my $epoch_seconds = shift;
  my $time = gmtime($epoch_seconds);
  sprintf("%04d%02d%02d%02d%02d%02d",
          $time->year + 1900,
          $time->mon + 1,
          $time->mday,
          $time->hour,
          $time->min,
          $time->sec)
}

sub field_type($) {
  my $field = shift;
  my ($type) = $field =~ /([SDI])$/;
  $type || ''
}

sub trim(@) {
  for (@_) {
    s/^\s+//, s/\s+$// if defined $_;
  }
}

sub upcase_first($) {
  my $value = shift;
  if ($value) {
    $value = uc(substr($value, 0, 1)) . substr($value, 1);
  }
  $value
}

sub milestone_identify_type($) {
  my $g = shift;
  for my $id (@MILESTONE_IDENTIFIER) {
    return $id if $$g{$id};
  }
  undef
}

sub milestone_parse_achieve($) {
  my $g = shift;
  $$g{mtype} = 'achieve';
  $$g{achieve_diff} = hexnum($$g{achieve_diff});
  $$g{mobj} = Henzell::Achieve::achievement_name($$g{achieve_diff});
  $$g{mdesc} = Henzell::Achieve::achievement_desc($$g{achieve_diff});
}

sub milestone_parse_shoplifted($) {
  my $g = shift;
  $$g{mdesc} = ("stole \$$$g{shoplifted} of merchandise from "
                . "$$g{shopkeeper} ($$g{shop})");
  $$g{mobj} = $$g{shopkeeper};
}

sub milestone_parse_sokobanprize($) {
  my $g = shift;
  $$g{mdesc} = "obtained the Sokoban prize ($$g{mobj})";
}

sub milestone_parse_bones_killed($) {
  my $g = shift;
  $$g{mdesc} = "killed the $$g{bones_monst} of $$g{mobj} the $$g{bones_rank}";
}

sub milestone_parse_killed_uniq($) {
  my $g = shift;
  $$g{mdesc} = "killed $$g{mobj}";
}

sub milestone_parse_killed_shk($) {
  my $g = shift;
  $$g{mobj} =~ s/'$//;
  $$g{mdesc} = "killed $$g{mobj}, the shopkeeper.";
}

sub milestone_parse_shout($) {
  my $g = shift;
  $$g{mdesc} = "shouted \"$$g{mobj}\"";
}

sub milestone_parse_crash($) {
  my $g = shift;
  $$g{mdesc} = "crashed the game";
}

sub milestone_parse_wish($) {
  my $g = shift;
  $$g{mdesc} = "wished for '$$g{mobj}'";
}

sub game_gender($) {
  my $g = shift;
  my $gender = $$g{gender};
  return $gender || 'Unk';
}

sub game_possessive_pronoun($) {
  my $g = shift;
  my $gender = game_gender($g);
  return "his" if $gender eq 'Mal';
  return 'her' if $gender eq 'Fem';
  return 'their';
}

sub milestone_parse_game_action($) {
  my $g = shift;
  my $pronoun = game_possessive_pronoun($g);
  $$g{mdesc} = "$$g{mobj} $pronoun game";
  $$g{mdesc} = "started a new game" if $$g{mobj} eq 'started';
}

# Figures out what kind of milestone this is and sets up data accordingly.
sub parse_milestone_record($) {
  my $g = shift;
  return $g if $$g{mtype} && $$g{mtype_finished};
  my $type = milestone_identify_type($g);
  $type = 'achieve_diff' if $type && $type =~ /achieve/;
  if ($type) {
    $$g{mtype} = $type;
    $$g{mobj} ||= $$g{$type} || $$g{obj};
    $$g{mdesc} = $$g{$type};
    my $parser = $MILESTONE_PARSER{$type};
    $parser->($g) if $parser;
    die "No mtype in $ORIG_LINE\n" unless $$g{mtype};
  } else {
    warn "Unknown milestone in '$ORIG_LINE'\n";
  }
}

sub fixup_milestone_record($) {
  my $g = shift;
  fixup_logfile_record($g);

  trim($$g{align});

  if ($$g{align} =~ /(\w+) (\w+)/) {
    $$g{align} = $1;
    $$g{gender} = $2;
  }

  # Strip overlong values and uppercase first letter.
  for (qw/alignment align gender race role/) {
    if ($$g{$_}) {
      $$g{$_} = upcase_first(substr($$g{$_}, 0, 3));
    }
  }

  parse_milestone_record($g);

  $g
}

sub hexnum {
  my $value = shift;
  return $value unless defined $value;
  hex($value)
}

sub fixup_logfile_record($) {
  my $g = shift;

  $$g{game} ||= game_from_filename($$g{file});
  $$g{name} ||= $$g{player};
  $$g{align} ||= $$g{alignment};
  $$g{placename} ||= $$g{dlev_name};

  die "Could not resolve game from $$g{file}\n" unless $$g{game};

  # Stub fields that may be missing.
  for (@LOGFIELDS_DECORATED) {
    my $type = field_type($_);
    my $field = strip_suffix($_);
    if (!defined($$g{$field})) {
      $$g{$field} = default_field_value($field, $type || '');
    }
  }

  $$g{dnum} ||= $$g{deathdnum};

  my $dnum = $$g{dnum};

  if (defined $dnum) {
    $$g{branch} = resolve_branch_name($$g{game},
                                      $$g{deathdnum} || $$g{dnum});
    $$g{lev} = $$g{deathlev};
    $$g{place} = $$g{branch};
    if (defined($$g{lev}) && $$g{branch} =~ /:$/) {
      $$g{place} = "$$g{branch}$$g{lev}";
    }
    s/:$// for $$g{branch};
  }

  $$g{deathmsg} = $$g{death};
  $$g{praying} = 'N';
  $$g{helpless} = 'N';
  $$g{amulet} = 'N';
  if ($$g{deathmsg}) {
    my $deathmsg = $$g{deathmsg};

    my ($while) = $deathmsg =~ /(, while .*)$/;
    $while ||= '';
    $deathmsg =~ s/, while .*$//;

    if ($deathmsg =~ s/\(with the Amulet\)//i) {
      $$g{amulet} = 'Y';
      trim($deathmsg);
    }

    my ($ktyp, $killer) = $deathmsg =~ /^(\w+)(?: by (.*))?/i;
    $$g{ktype} = $ktyp;

    $killer ||= '';
    for ($killer) {
      s/^an? //;
      s/^the //;
      s/^invisible// unless /stalker/;
      s/ of .*// if /^Angel/;
    }

    $$g{killer} = $killer;
    $$g{ckiller} = $killer || $ktyp;
    $$g{praying} = 'Y' if $while =~ /while praying/i;
    if ($while =~ /, while (.*)/i) {
      $$g{helpless} = 'Y';
      $$g{kstate} = $1;
    }
  }

  $$g{starttime} = utc_epoch_seconds_to_fulltime($$g{starttime});
  $$g{endtime} = utc_epoch_seconds_to_fulltime($$g{endtime});
  $$g{currenttime} = utc_epoch_seconds_to_fulltime($$g{currenttime});

  for (qw/achieve conduct/) {
    $$g{$_} = hexnum($$g{$_});
  }
  my @achievements = Henzell::Achieve::achievement_names($$g{achieve} || 0);
  my @conducts = Henzell::Achieve::conduct_names($$g{conduct} || 0);
  $$g{achieve} = join(",", @achievements);
  $$g{conduct} = join(",", @conducts);
  $$g{nachieve} = scalar(@achievements);
  $$g{nconduct} = scalar(@conducts);

  $g
}

sub fixup_logfields {
  my $g = shift;

  my $milestone = xlog_is_milestone($g);
  $$g{cversion} = $$g{version};

  if ($milestone) {
    fixup_milestone_record($g);
  } else {
    fixup_logfile_record($g);
  }
  $$g{placename} ||= $$g{place};
  $$g{place} ||= $$g{placename};

  $g
}

sub field_val {
  my ($key, $g) = @_;
  my $ftype = field_type($key);
  $key = strip_suffix($key);
  my $val = $g->{$key} || default_field_value($key, $ftype);
  $val =~ tr/_/ / if $val;
  $val
}

sub record_is_alpha_version {
  my ($lf, $g) = @_;
  return 'y' if $$lf{alpha};

  # Game version that mentions -rc or -a is automatically alpha.
  my $v = $$g{version} || '';
  return 'Y' if $v =~ /-(?:rc|a)/i;

  return '';
}

sub milestone_is_useless($) {
  my $m = shift;

  my $type = $$m{mtype} || '';
  my $obj = $$m{mobj} || '';

  # Discard game actions and shouts.
  (($type eq 'game_action'
    && grep($_ eq $obj, qw/saved resumed started/))
   || $type eq 'shout')
}

sub add_milestone {
  my ($lf, $offset, $line) = @_;

  chomp $line;
  my $m = parse_logline($line, $lf->{file});

  $ORIG_LINE = $line;
  $m->{file} = $lf->{file};
  $m->{offset} = $offset;
  $m->{src} = $lf->{server};
  $m->{alpha} = record_is_alpha_version($lf, $m);
  $m->{milestone} ||= '?';
  eval {
    $m = fixup_logfields($m);
  };
  die "Failed to parse '$line': $@" if $@;
  return unless $$m{mtype} && !milestone_is_useless($m);

  my $st = $milestone_insert_st;
  my @bindvals = map(field_val($_, $m), @MILE_INSERTFIELDS_DECORATED);
  execute_st($st, @bindvals) or
    die "Can't insert record for $line: $!\n";
}

sub add_logline {
  my ($lf, $offset, $line) = @_;
  chomp $line;
  $ORIG_LINE = $line;
  my $fields = logfield_hash($line);
  $fields->{src} = $lf->{server};
  $fields->{alpha} = record_is_alpha_version($lf, $fields);
  $fields->{file} = $lf->{file};

  eval {
    $fields = fixup_logfields($fields);
  };
  die "Failed to parse '$line': $@" if $@;

  my $st = $insert_st;
  my @bindvalues = ($lf->{file}, $lf->{server}, $offset,
                    map(field_val($_, $fields), @LOGFIELDS_DECORATED));
  execute_st($st, @bindvalues) or
    die "Can't insert record for $line: $!\n";
}

sub xlog_escape {
  my $str = shift() || '';
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
