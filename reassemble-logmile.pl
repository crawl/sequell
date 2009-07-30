#! /usr/bin/perl

use strict;
use warnings;

use DBI;

my $version = '0.5';
my $REBUILT_LOGFILE = 'logfile-rebuilt';
my $REBUILT_MILESTONES = 'milestones-rebuilt';

# Log field names. These are logfile names, although rstart, rend, and rtime
# are Henzell db column names instead.
my @RLOGF = qw/v lv sc name uid race cls char
  xl sk sklev title ktyp killer kaux place br lvl
  ltyp hp mhp mmhp dam str int dex god piety pen wiz rstart
  rend dur turn urune nrune tmsg vmsg/;

my @RMILEF =
    qw/v name race cls char xl sk sklev title
       place br lvl ltyp hp mhp mmhp str int dex god
       dur turn urune nrune rstart rtime verb noun milestone/;

our %LOG2SQL = ( name => 'pname',
                 char => 'charabbrev',
                 str => 'sstr',
                 dex => 'sdex',
                 int => 'sint',
                 start => 'tstart',
                 end => 'tend',
                 time => 'ttime');

# Map field names from Henzellese to logfilese or milestonese.
my %HENZELL_TO_LOG =
  (
   rstart => 'start',
   rend => 'end',
   rtime => 'time'
  );

reconstruct_files();

sub new_db_handle {
  DBI->connect("dbi:mysql:henzell", 'henzell', '')
}

sub run_query {
  my ($db, $query) = @_;
  my $st = $db->prepare($query) or die "Can't prepare $query: $!\n";
  $st->execute() or die "Query $query failed: $!\n";
  $st
}

sub xlog_escape {
  my $field = shift;
  $field =~ s/:/::/g;
  $field
}

sub xlog_str {
  my $hash = shift;
  my @keys = sort(keys %$hash);
  join(":", map("$_=" . xlog_escape($$hash{$_}), sort(keys %$hash)))
}

sub reconstruct_xfile {
  my ($db, $file, $table, @fields) = @_;

  open my $outf, '>', $file or die "Can't write $file: $!\n";
  push @fields, 'offset';
  my @sqlfields = map($LOG2SQL{$_} || $_, @fields);
  my $query = ('SELECT ' . join(", ", @sqlfields) . ' FROM ' . $table
               . " WHERE v = '$version' AND src='cao' ORDER BY id");
  print "Rebuilding $file using $query\n";
  my $st = run_query($db, $query);
  my $lastrow;
  my $lastrowsz;
  my $lastrowoffset;
  my $offset = 0;
  while (my $row = $st->fetchrow_arrayref) {
    my %table;
    my @henzell_fields = map($HENZELL_TO_LOG{$_} || $_, @fields);
    @table{@henzell_fields} = @$row;

    my $diff = $table{offset} - $offset;
    if ($diff > 10 || $diff < 0) {
      die "Row at wrong offset ($offset, wanted $table{offset}), possibly because of previous row: $lastrow\n";
    }

    # Oops, are we short on a few characters? FAKE IT!
    my $padding = '';
    if ($diff) {
      # Arr, pad it out, me hearties!
      $padding = ' ' x $diff;
    }

    $lastrowoffset = $table{offset};
    delete $table{offset};
    for (qw/nrune urune wiz pen god kaux piety vmsg killer/) {
      delete $table{$_} if exists $table{$_} && !$table{$_};
    }
    $lastrow = $padding . xlog_str(\%table);
    $lastrowsz = length($lastrow) + 1;
    $offset += $lastrowsz;
    print $outf "$lastrow\n";
  }
  close $outf;
}

sub reconstruct_logfile {
  my ($db, $file) = @_;
  reconstruct_xfile($db, $file, 'logrecord', @RLOGF);
}

sub reconstruct_milestones {
  my ($db, $file) = @_;
  reconstruct_xfile($db, $file, 'milestone', @RMILEF);
}

sub reconstruct_files {
  my $db = new_db_handle();
  print "Rebuilding logfiles and milestones ",
    "(to $REBUILT_LOGFILE/$REBUILT_MILESTONES)\n";
  reconstruct_logfile($db, $REBUILT_LOGFILE);
  reconstruct_milestones($db, $REBUILT_MILESTONES);
}
