#! /usr/bin/env perl

use strict;
use warnings;
use Time::localtime;
use File::stat;
use Henzell::Cmd;

$ENV{HENZELL_SQL_QUERIES} = 'y';

require 'sqllog.pl';

my $DB_DIRTY;
my $DBNAME = 'henzell_test';
my $DBUSER = 'henzell';
my $DBPASS = '';

$ENV{'HENZELL_DBNAME'} = $DBNAME;
$ENV{'HENZELL_DBUSER'} = $DBUSER;
$ENV{'HENZELL_DBPASS'} = $DBPASS;

new_db_handle($DBNAME, $DBUSER, $DBPASS) && initialize_sqllog();

my $SCHEMAFILE = 'henzell.sql';
my $TESTFILE = 'testcmd.txt';

my $TESTLOG = 'test.log';
my $TESTDIR = 'tests';
my $DATADIR = "$TESTDIR/data";
my @LOGFILES = qw/remote.cdo-logfile-svn remote.cdo-logfile-spr
                  remote.cdo-logfile-zd/;
my @MILEFILES = qw/remote.cdo-milestones-svn
                   remote.cdo-milestones-spr
                   remote.cdo-milestones-zd/;

my @COMMAND_FILES = ('commands/commands-henzell.txt',
                     'commands/commands-sequell.txt');


my @FAILED_TESTS;
my @OK_TESTS;

my $TESTNICK = 'hyperbolic';

my $TIMESTAMP_QUERY = <<QUERY;
SELECT last_update FROM canary;
QUERY

sub announce($) {
  print STDERR "* ", @_, "\n";
}

sub test_ok($) {
  my $test = shift;
  push @OK_TESTS, $test;
}

sub test_failed($$) {
  my ($test, $failure) = @_;
  push @FAILED_TESTS, { test => $test, failure => $failure };
}

sub datafile_logs() {
  @LOGFILES
}

sub datafile_milestones() {
  @MILEFILES
}

sub datafiles() {
  (datafile_logs(), datafile_milestones())
}

sub datafile_path($) {
  "$DATADIR/" . shift
}

sub datafile_hashrefs(@) {
  map({ file => datafile_path($_),
        path => datafile_path($_),
        src => 'cdo' },
      @_)
}

sub check_datafiles_exist() {
  for my $file (map(datafile_path($_), datafiles())) {
    die "Cannot find data file \"$file\"\n" unless -r $file;
  }
}

sub datafiles_newest_time() {
  my $newest;
  for my $file (map(datafile_path($_), datafiles())) {
    my $mtime = stat($file)->mtime;
    $newest = $mtime if !$newest || $mtime > $newest;
  }
  $newest = time_to_dbdate(localtime($newest)) if $newest;
  $newest
}

sub with_db(&) {
  my $sub = shift;
  my $db = new_db_handle($DBNAME, $DBUSER, $DBPASS);
  my $result = $sub->($db);
  $db->disconnect;
  $result
}

sub db_schema_missing() {
  my $schema_missing = with_db {
    my $dbh = shift;
    !$dbh->selectall_arrayref($TIMESTAMP_QUERY);
  };
  announce "DB schema is missing or incomplete" if $schema_missing;
  $schema_missing
}

sub db_canary_time() {
  with_db {
    my $dbh = shift;
    my $ref = $dbh->selectall_arrayref($TIMESTAMP_QUERY);
    return $ref && @$ref? $ref->[0][0] : undef;
  }
}

sub execute_statement($$@) {
  my ($dbh, $text, @values) = @_;
  my $st = $dbh->prepare_cached($text)
    or die "Malformed statement: $text\n";
  $st->execute(@values);
  $st
}

sub db_canary_set_time() {
  with_db {
    my $dbh = shift;
    $dbh->do("DELETE FROM canary");
    execute_statement($dbh, "INSERT INTO canary (last_update) VALUES (?)",
                      time_to_dbdate(localtime()));
  }
}

sub db_timestamp_stale {
  my $canary_time = db_canary_time();

  my $datafiles_newest_time = datafiles_newest_time();
  if ($canary_time && $datafiles_newest_time &&
      $datafiles_newest_time gt $canary_time)
  {
    announce("DB $DBNAME needs update: last updated: $canary_time, " .
             "newest datafile: $datafiles_newest_time")
  }
  !$canary_time || $datafiles_newest_time gt $canary_time
}

sub db_load_schema() {
  announce "Rebuilding schema from $SCHEMAFILE";
  with_db {
    my $dbh = shift;
    my $sql_ddl = do { local (@ARGV, $/) = $SCHEMAFILE; <> };
    my @ddl_statements = split(/;/, $sql_ddl);
    for my $statement (@ddl_statements) {
      $dbh->do($statement)
        or die "Failed to load schema: error $! on $statement\n";
    }
  };
}

sub db_load_data() {
  with_db {
    my $dbh = shift;
    my $timestamp = localtime();
    for my $logfile (open_handles(datafile_hashrefs(datafile_logs()))) {
      announce "Loading logfile data from $$logfile{file}";
      sql_register_logfiles($logfile->{file});
      cat_logfile($logfile);
    }
    for my $milestone (open_handles(datafile_hashrefs(datafile_milestones()))) {
      announce "Loading milestone data from $$milestone{file}";
      sql_register_milestones($milestone->{file});
      cat_stonefile($milestone);
    }
  };
}

sub time_to_dbdate($) {
  my $time = shift;
  sprintf("%04d-%02d-%02d %02d:%02d:%02d",
          $time->year() + 1900,
          $time->mon() + 1,
          $time->mday(),
          $time->hour(),
          $time->min(),
          $time->sec())
}

sub dbdate_to_time($) {
  my $dbdate = shift;
  print "DB date: $dbdate\n";
  $dbdate
}

sub build_test_db() {
  $DB_DIRTY = db_schema_missing() || db_timestamp_stale();
  if ($DB_DIRTY) {
    announce "Database needs update";
    db_load_schema();
    db_load_data();
    db_canary_set_time();
  }
}

sub trim($) {
  my $text = shift;
  s/^\s+//, s/\s+// for $text;
  $text
}

sub parse_test($) {
  my %test;
  my $text = shift;
  if ($text =~ s/^E\s+(.*)/$1/) {
    $test{err} = 1;
  }
  die "Malformed test line\n" unless $text =~ /\S/;
  my ($cmd) = $text =~ /^(\S+)/;
  die "Unknown command $cmd in test '$text'\n"
    unless Henzell::Cmd::command_exists($cmd);
  $test{cmd} = $cmd;

  if ($text =~ /::(!?)~(.*)/) {
    my $key = $1? 'regex_not_match' : 'regex_match';
    $test{$key} = trim($2);
  }
  if ($text =~ /::(!?)=(.*)/) {
    my $key = $1? 'exact_not_match' : 'exact_match';
    $test{$key} = trim($2);
  }
  $text =~ s/\s+::!?[~=].*//;
  $test{line} = $text;
  \%test
}

sub read_tests() {
  my $file = "tests/$TESTFILE";
  open my $inf, '<', $file or die "Can't read tests from $file: $!\n";
  my @tests;
  while (<$inf>) {
    chomp;
    s/^\s+//, s/\s+$//;
    next if /^#/;
    next unless /\S/;

    push @tests, parse_test($_);
  }
  @tests
}

sub execute_cmd($) {
  Henzell::Cmd::execute_cmd($TESTNICK, shift)
}

sub execute_test($$) {
  my ($test, $logf) = @_;
  my ($exitcode, $output, $cmd) = execute_cmd($$test{line});
  $$test{cmdline} = $cmd;
  print $logf <<TESTREPORT;
-----------------------------------------------------------------------
$$test{line}::
Command line: $cmd
Exit code: $exitcode
Output:
$output
TESTREPORT

  my $err =
    $exitcode && !$$test{err}? "$cmd error:\n$output\n" :
    $$test{regex_match} && $output !~ /$$test{regex_match}/m?
      ("Output does not contain expected match: " .
       "$$test{regex_match}: $output") :
    $$test{regex_not_match} && $output =~ /$$test{regex_not_match}/m?
      ("Output contains forbidden match: " .
       "$$test{regex_not_match}: $output") :
    $$test{exact_match} && $output ne $$test{exact_match}?
      ("Output does not exactly equal " .
       "expected '$$test{exact_match}': $output") :
    $$test{exact_not_match} && $output eq $$test{exact_not_match}?
      ("Output equals forbidden output '$$test{exact_not_match}" .
       ": $output") :
    '';
  if ($err) {
    print $logf "Error: $err\n";
    test_failed($test, $err);
    return;
  }
  print $logf "TEST SUCCESS\n";
  test_ok($test);
}

sub test_failure_report($) {
  my $failure = shift;
  my $test = $failure->{test};
  my $err = $failure->{failure};
  my $header = "--------------------------------------------------";
  return ("$header\nTest: $$test{cmd}\nCommand line: $$test{cmdline}"
          . "\nError: $err\n$header\n");
}

sub test_summary($) {
  my $logf = shift;
  print $logf <<ENDBANNER;

============================================================================
ENDBANNER
  my $ok = @OK_TESTS;
  my $fail = @FAILED_TESTS;
  my $total = $ok + $fail;
  print $logf "$total tests executed, $fail failures, $ok successful.\n";
  if ($fail) {
    print $logf "Failing tests:\n" . join("\n",
                                          map(test_failure_report($_),
                                              @FAILED_TESTS)) . "\n";
  }
  print $logf <<ENDBANNER2;
============================================================================
ENDBANNER2
}

sub run_tests() {
  Henzell::Cmd::load_all_commands();
  my @tests = read_tests();
  announce "Running " . scalar(@tests) . " tests";
  open my $logf, '>', $TESTLOG or die "Can't write $TESTLOG: $!\n";
  for my $test (@tests) {
    execute_test($test, $logf);
  }
  test_summary($logf);
  test_summary(\*STDERR);
}

sub main() {
  check_datafiles_exist();
  build_test_db();
  run_tests();
  exit(!!scalar(@FAILED_TESTS));
}

main();
