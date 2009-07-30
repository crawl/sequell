#! /usr/bin/perl

use strict;
use warnings;

use File::Temp qw/tempfile/;
use File::Copy;
use Fcntl qw/:flock SEEK_SET/;
use IO::Handle;

# Given a file and a prefix, locks file, copies it out elsewhere, applies
# all lines from the prefix file, then reappends lines originally present
# in the file.

my ($prefix, $target) = @ARGV;

die "Usage: $0 <prefix> <target>; read source, this is not a toy\n"
  unless $prefix && $target;

# Both files should exist
die "Prefix file $prefix does not exist or is not readable\n" unless -r $prefix;
die "Target file $target does not exist or is not read/writable\n"
  unless -r $target && -w $target;

# Prefix file should be in the current directory.
die "Prefix filename contains /. Please read the source!\n" if $prefix =~ m{/};
die "Target filename does not contain /. Please read the source!\n"
  if $target !~ m{/};

# Do the names sound reasonable?
if (($prefix =~ /logfile/) != ($target =~ /logfile/)
    || ($prefix =~ /milestone/) != ($target =~ /milestone/))
{
  die "$prefix and $target look like different kinds of files. Do you know what you're doing?\n";
}

print "Ok, I'm going to do the equivalent of cat $prefix $target > $target.\n";
print "Is this what you want? READ CAREFULLY and enter 'yes' to continue.\n\n";
print "You REALLY want to back up $target before you say 'yes': ";

chomp(my $ack = <STDIN>);
die "User aborted\n" unless $ack eq 'yes';

print "\n\nSo be it.\n";
prefix_logfile($prefix, $target);

sub count_lines {
  my $file = shift;
  chomp(my $lines = qx/wc -l $file/);
  my ($count) = (split ' ', $lines)[0];
  die "Bad line count: $count in $lines\n" unless $count =~ /^[0-9]+$/;
  return $count;
}

sub copy_lines_from_to {
  my ($src, $dst) = @_;
  while (<$src>) {
    print $dst $_;
  }
}

sub prefix_logfile {
  my ($prefix, $target) = @_;

  open my $targh, '+<', $target or die "Can't open $target read/write\n";
  open my $prefh, '<', $prefix or die "Can't read $prefix: $!\n";
  flock $targh, LOCK_EX or die "Could not lock $target\n";

  # Gather useful statistics to sanity-check results
  my $prefix_size = -s $prefix;
  my $target_size = -s $target;
  my $prefix_lines = count_lines($prefix);
  my $target_lines = count_lines($target);

  my ($fh, $temp_filename) = tempfile();
  close $fh;
  copy($target, $temp_filename) or die "Couldn't back up $target to temp file $temp_filename: $!\n";

  # Paranoia - are the temp file and target the same size?
  if ($target_size != -s($temp_filename)) {
    die ("Copied $target to $temp_filename but original file size $target_size "
         . "changed to " . (-s $temp_filename) . "\n");
  }

  my $copy_lines = count_lines($temp_filename);
  die "Copied $target to $temp_filename but original line count $target_lines changed to $copy_lines\n" if $copy_lines != $target_lines;

  # Looking good! TRUNCATE.
  print "Truncating $target. I hope you had a backup if this goes wrong. :P\n";
  truncate($targh, 0);

  seek($targh, 0, SEEK_SET);
  # Ok, read lines from $prefix into $target

  copy_lines_from_to($prefh, $targh);

  # Snazzy. Now copy the original contents of target back on top.
  open my $temph, '<', $temp_filename or die "Can't re-read $temp_filename: $!\n";
  copy_lines_from_to($temph, $targh);

  # Aaawesome. Flush and sync to disk now.
  $targh->flush();
  $targh->sync();

  # Sanity-checks redux. New file size should be equal to the sum of
  # the old sizes.
  my $new_size = -s $target;
  if ($new_size != $prefix_size + $target_size) {
    die ("New size of $new_size is not the expected "
         . "$prefix_size + $target_size (" . ($prefix_size + $target_size)
         . ")");
  }

  # And we want the line counts to add up too!
  my $new_linecount = count_lines($target);
  my $expected_linecount = $prefix_lines + $target_lines;
  if ($new_linecount != $expected_linecount) {
    die ("New line count $new_linecount is not what I expected: " .
         "$expected_linecount ($prefix_lines + $target_lines)\n");
  }
  # We seem to have satisfied all checks, yowza.
  close $targh;
  close $prefh;
  close $temph;

  print "\n\nEverything seems to have gone ok!\n";
}
