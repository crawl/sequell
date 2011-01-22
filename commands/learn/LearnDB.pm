#!/usr/bin/perl

package LearnDB;

use strict;
use warnings;
use File::Temp qw/tempfile/;
use File::Path qw/mkpath/;

use base 'Exporter';

our @EXPORT = qw/cleanse_term num_entries read_entry print_to_entry
                 entries_for del_entry replace_entry swap_entries
                 check_entry_exists report_error
                 insert_entry $RTERM $RTERM_INDEXED $RTEXT/;

our $learn_dir = 'dat/learndb/';

our $RTERM = qr/([\w!]+)/;
our $RTERM_INDEXED = qr/([\w!]+)\[(\d+)\]/;
our $RTEXT = qr/(.+)/;

our $TERM_MAX_LENGTH = 30;
our $TEXT_MAX_LENGTH = 350;

sub term_directory($) {
  my ($term) = @_;
  $term = cleanse_term($term);
  "$learn_dir$term"
}

sub term_filename($;$) {
  my ($term, $num) = @_;
  $num ||= '1';
  term_directory($term) . "/$num"
}

sub term_exists($;$) {
  my ($term, $num) = @_;
  -r term_filename($term, $num)
}

sub cleanse_term
{
  my $term = lc(shift);

  $term =~ y/ /_/;
  $term =~ s/^_+//;
  $term =~ s/_+$//;

  $term =~ y/a-z0-9_!//cd;
  return $term;
}

sub num_entries
{
  my $term = cleanse_term(shift);

  opendir(my $dir, term_directory($term)) or 0;
  my @files = grep {$_ ne "." and $_ ne ".." and $_ ne "contrib"}
              readdir $dir;
  return scalar @files;
}

sub check_entry_exists($;$) {
  my ($term, $num) = @_;
  if (!-r term_filename($term, $num)) {
    if ($num) {
      die "I don't have a page labeled $term\[$num] in my learndb.";
    }
    else {
      die "I don't have a page labeled $term in my learndb.";
    }
  }
}

sub read_entry
{
  my $term = cleanse_term(shift);
  my $entry_num = shift;
  my $just_the_entry = shift || 0;

  my $file = "$learn_dir$term/$entry_num";
  return '' if not -r $file;
  my $contents = do {local @ARGV = $file; <>};
  return $contents if $just_the_entry;

  $term =~ y/_/ /;

  return sprintf '%s[%d/%d]: %s', $term, $entry_num, num_entries($term), $contents;
}

sub print_to_entry
{
  my $term = cleanse_term(shift);
  my $entry_num = shift;
  my $text = shift;

  my $file = "$learn_dir$term/$entry_num";
  open(my $handle, ">", $file) or die "Unable to open $file for writing: $!";
  print {$handle} $text;
}

sub entries_for
{
  my $term = cleanse_term(shift);
  my @entries;
  my $num = 0;
  my $entries = num_entries($term);

  foreach my $num (1..$entries)
  {
    $entries[$num] = read_entry($term, $num);
  }

  return \@entries;
}

sub check_thing_length($$$) {
  my ($thing, $term, $length) = @_;
  if (length($term) > $length) {
    die "$thing exceeds the maximum length of $length\n";
  }
  if ($term eq '') {
    die "$thing is empty\n";
  }
}

sub check_term_length($) {
  check_thing_length("Term name", cleanse_term(shift), $TERM_MAX_LENGTH);
}

sub check_text_length($) {
  check_thing_length("Entry text", shift, $TEXT_MAX_LENGTH);
}

sub renumber_entry_item($$$) {
  my ($term, $num, $newnum) = @_;
  my $old_filename = term_filename($term, $num);
  my $new_filename = term_filename($term, $newnum);
  die "Cannot find $term\[$num]\n" unless -f $old_filename;
  die "Cannot move $term\[$num] to $term\[$newnum]: target exists\n"
    if -f $new_filename;
  rename($old_filename, $new_filename)
    or die "Could not rename $term\[$num] to $term\[$newnum]: $!\n"
}

sub insert_entry {
  my ($term, $num, $text) = @_;
  $term = cleanse_term($term);
  check_term_length($term);
  check_text_length($text);
  mkpath(term_directory($term));
  my $entrycount = num_entries($term);
  $num = $entrycount + 1 if $num > $entrycount || $num < 1;
  for (my $i = $entrycount; $i >= $num; --$i) {
    renumber_entry_item($term, $i, $i + 1);
  }
  print_to_entry($term, $num, $text);
  return read_entry($term, $num);
}

sub del_entry
{
  my $term = cleanse_term(shift);
  my $entry_num = shift;
  my $moves = 0;

  my @files = (1..num_entries($term));

  #if ($term == "bad_ideas")
  #{
  #  return read_entry('raxvulpine', 2);
  #}

  return -1 if $entry_num > $files[-1];

  if ($entry_num == $files[-1])
  {
    if ($entry_num == 1)
    {
      system("rm -r '$learn_dir$term/'");
    }
    else
    {
      system("rm '$learn_dir$term/$entry_num'");
    }
    return 0;
  }

  foreach my $file (@files)
  {
    if ($file > $entry_num)
    {
      my $src = "$learn_dir$term/$file";
      my $dest = "$learn_dir$term/" . ($file-1);
      system("mv '$src' '$dest'");
      $moves++;
    }
  }

  return $moves;
}

sub replace_entry
{
  my $term = cleanse_term(shift);
  my $entry_num = shift;
  my $new_text = shift;

  opendir(my $dir, "$learn_dir$term") or return undef;
  foreach my $file (readdir $dir)
  {
    next if $file eq "." or $file eq "..";
    next if $file eq "contrib";
    if ($file == $entry_num)
    {
      print_to_entry($term, $entry_num, $new_text);
      return 1;
    }
  }

  return 0;
}

sub swap_entries
{
  my $term1 = cleanse_term(shift);
  my $entry_num1 = shift;
  my $term2 = cleanse_term(shift);
  my $entry_num2 = shift;

  my $file1 = "$learn_dir$term1/$entry_num1";
  my $file2 = "$learn_dir$term2/$entry_num2";
  my ($fh, $tempfile) = tempfile;
  close $fh;

  system("cp '$file1' '$tempfile'") and return;
  system("cp '$file2' '$file1'") and return;
  system("cp '$tempfile' '$file2'") and return;
  system("rm '$tempfile'");

  return 1;
}

sub rename_entry($$) {
  my ($src, $dst) = @_;
  rename(term_directory($src), term_directory($dst))
    or die "Couldn't move $src to $dst\n";
}

sub move_entry($$$;$) {
  my ($src, $snum, $dst, $dnum) = @_;
  check_term_length($src);
  check_term_length($dst);
  if (!$snum) {
    check_entry_exists($src, 0);
    die "$dst exists, cannot overwrite it.\n" if term_exists($dst);
    rename_entry($src, $dst);
    return "$src -> " . read_entry($dst, 1);
  }
  else {
    check_entry_exists($src, $snum);
    my $src_entry = read_entry($src, $snum, 'just-the-entry');
    del_entry($src, $snum);
    return "$src\[$snum] -> " . insert_entry($dst, $dnum || -1, $src_entry);
  }
}

sub report_error($) {
  my $error = shift;
  $error =~ s/ at \S+ line.*$//;
  print $error
}

1;
