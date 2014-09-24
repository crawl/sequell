#! /usr/bin/env perl

use strict;
use warnings;
use utf8;
use Time::localtime;
use File::stat;

use lib 'lib';
use Henzell::Cmd;
use Henzell::DB;
use Henzell::CommandService;

use open qw/:std :encoding(UTF-8)/;

$ENV{LEARNDB} = 'tmp/test.learn.db';
$ENV{HENZELL_SQL_QUERIES} = 'y';
$ENV{HENZELL_TEST} = 'y';
$ENV{RUBYOPT} = '-rubygems -Isrc';
$ENV{HENZELL_ALL_COMMANDS} = 'y';
$ENV{PERL_UNICODE} = 'AS';
$ENV{IRC_NICK_AUTHENTICATED} = 'y';

mkdir 'tmp';
unlink $ENV{LEARNDB};

my $DB_DIRTY;
my $DBNAME = 'sequell_test';
my $DBUSER = 'sequell';
my $DBPASS = '';

$ENV{'SEQUELL_DBNAME'} = $DBNAME;
$ENV{'SEQUELL_DBUSER'} = $DBUSER;
$ENV{'SEQUELL_DBPASS'} = $DBPASS;

my $FAILFAST;
my $TESTFILE = 'testcmd.txt';

my $TESTLOG = 'test.log';
my $TESTDIR = 'tests';
my $DATADIR = "$TESTDIR/data";

my @COMMAND_FILES = glob('config/commands-*.txt');

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

sub datafiles() {
  grep(m{/remote[.]}, glob("$DATADIR/*"))
}

sub datafiles_newest_time() {
  my $newest;
  for my $file (datafiles()) {
    my $mtime = stat($file)->mtime;
    $newest = $mtime if !$newest || $mtime > $newest;
  }
  $newest = time_to_dbdate(localtime($newest)) if $newest;
  $newest
}

sub with_db(&) {
  my $sub = shift;
  my $db = Henzell::DB::new_db_handle($DBNAME, $DBUSER, $DBPASS);
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

sub db_reset() {
  announce("Rebuilding schema for $DBNAME");
  system("seqdb --db $DBNAME resetdb --force");

  with_db {
    my $dbh = shift;
    my $res = $dbh->do(<<CREATE_CANARY);
create table canary (last_update timestamp);
CREATE_CANARY

    $res or die "Failed to create canary table: $!";
  };
}

sub db_load_data() {
  announce("Loading data into $DBNAME");
  system("seqdb --db $DBNAME load --force-source-dir $DATADIR") and
    die "Couldn't load data into $DBNAME: $!\n";
}

sub db_create_indexes() {
  announce("Creating indexes for $DBNAME");
  system("seqdb --db $DBNAME create-indexes") and
    die "Couldn't create indexes for $DBNAME: $!\n";
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
    db_reset();
    db_load_data();
    db_canary_set_time();
    db_create_indexes();
  }
}

sub trim($) {
  my $text = shift;
  s/^\s+//, s/\s+$// for $text;
  $text
}

sub parse_test($) {
  my %test;
  my $text = shift;

  if ($text =~ /^\$\s*(.*)/) {
    $test{shell} = $1;
    return \%test;
  }

  if ($text =~ s/^E\s+(.*)/$1/) {
    $test{err} = 1;
  }
  die "Malformed test line\n" unless $text =~ /\S/;
  my ($cmd) = $text =~ /^(\S+)/;
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
  Henzell::Cmd::load_all_commands();
  Henzell::Cmd::execute_cmd($TESTNICK, shift)
}

sub execute_test($$) {
  my ($test, $logf) = @_;

  if ($$test{shell}) {
    my $output = qx/$$test{shell} 2>&1/;
    print $logf <<TESTREPORT;
SHELL EXEC: $$test{shell}
Output:
$output
TESTREPORT
    return;
  }

  my ($exitcode, $output, $cmd) = execute_cmd($$test{line});
  $output = Henzell::CommandService->handle_output($output, 1) || '';
  chomp $output;
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
    ($exitcode && !$$test{err}) ? "$cmd error:\n$output\n" :
    (!$exitcode && $$test{err}) ? "$cmd ok, but expected error:\n$output\n" :
    $$test{regex_match} && $output !~ /$$test{regex_match}/m?
      ("Output '$output' does not contain expected match: " .
       "$$test{regex_match}: $output") :
    $$test{regex_not_match} && $output =~ /$$test{regex_not_match}/m?
      ("Output '$output' contains forbidden match: " .
       "$$test{regex_not_match}: $output") :
    $$test{exact_match} && $output ne $$test{exact_match}?
      ("Output '$output' does not exactly equal " .
       "expected '$$test{exact_match}': $output") :
    $$test{exact_not_match} && $output eq $$test{exact_not_match}?
      ("Output equals forbidden output '$$test{exact_not_match}" .
       ": $output") :
    '';
  if ($err) {
    print $logf "Error: $err\n";
    test_failed($test, $err);
    return 1;
  }
  print $logf "TEST SUCCESS\n";
  test_ok($test);
  return;
}

sub test_failure_report($) {
  my $failure = shift;
  my $test = $failure->{test};
  my $err = $failure->{failure};
  my $header = "--------------------------------------------------";
  return ("$header\nTest: $$test{line}\nCommand line: $$test{cmdline}"
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

sub matches_argv_filter($) {
  my $test = shift;
  return scalar(grep($$test{line} =~ /^\Q$_/, @ARGV));
}

sub filter_tests(@) {
  my @tests = @_;
  return @tests unless @ARGV;
  grep($$_{shell} || matches_argv_filter($_), @tests)
}

sub run_tests() {
  Henzell::Cmd::load_all_commands();
  my @tests = filter_tests(read_tests());
  my $test_count = grep(!$$_{shell}, @tests);
  announce "Running $test_count tests";
  open my $logf, '>', $TESTLOG or die "Can't write $TESTLOG: $!\n";
  for my $test (@tests) {
    last if execute_test($test, $logf) && $FAILFAST;
  }
  test_summary($logf);
  test_summary(\*STDERR);
}

sub main() {
  $FAILFAST = grep(/--fail-fast/, @ARGV);
  @ARGV = grep(!/^--/, @ARGV);
  build_test_db();
  run_tests();
  exit(!!scalar(@FAILED_TESTS));
}

main();
