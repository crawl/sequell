#! /usr/bin/perl

use strict;
use warnings;

use lib 'commands';
use Helper;
use File::Copy;
use File::Path;
use POSIX qw/strftime/;

my $VERSION = '0.5';

my $SAVEDIR_PATH = "/home/crawl/chroot/var/games/crawl05/saves/";
my $DESTINATION = "/home/henzell/copied-saves";

my $SAVE_NAME_SUFFIX = "-5.";

my $HELPTEXT = "Backs up a $VERSION save into a drop-box where "
  . "the server admin or DevTeam can find it later. Please use this only "
  . "to aid in reporting bugs.";
my $USAGETEXT = "Usage: !copysave <caoname> <reason>. " .
  "Name is case-sensitive. Reason must non-empty.";
my $EADMIN = "Please notify the server admin of this problem.";

Helper::help("$HELPTEXT $USAGETEXT");

my $arg = $ARGV[2];
Helper::error($USAGETEXT) unless $arg =~ /^!\w+\s+(\w+)\s+(\S.*)/;

my ($name, $reason) = ($1, $2);
my $qualifier = strip_reason($reason);

if (!$qualifier) {
  Helper::error("$USAGETEXT. Please use actual words in your " .
                "error description.");
}

backup_save($name, $qualifier);

sub strip_reason {
  my $reason = shift;
  $reason =~ tr/a-zA-Z0-9/_/cs;
  $reason
}

sub backup_save {
  my ($name, $qualifier) = @_;

  # Paranoia.
  Helper::error("Unexpected characters in $name") unless $name =~ /^\w+$/;

  # [snark] I'm deliberately making these globs rather specific here so we
  # don't sweep in files we don't want.
  my @files = glob("$SAVEDIR_PATH/$name${SAVE_NAME_SUFFIX}*");
  Helper::error("Cannot find save for $name.") unless @files;

  copy_pieces(@files);
  my $backup_name = tar_pieces($name, $qualifier);
  cleanup_pieces($name);
  print "Successfully backed up ${name}'s save as $backup_name.\n";
}

sub copy_pieces {
  unless (-d $DESTINATION) {
    mkpath($DESTINATION) or
      Helper::error("Failed to find location to backup saves. $EADMIN");
  }
  for my $file (@_) {
    copy($file, $DESTINATION)
      or Helper::error("Failed to backup a save file. $EADMIN");
  }
}

sub cleanup_pieces {
  my $name = shift;

  chdir $DESTINATION
    or Helper::error("Failed to cd to backup location. $EADMIN");

  # Paranoia, enforce safe characters in name.
  Helper::error("Bogus characters in $name. $EADMIN")
      unless $name =~ /^\w+$/;

  for my $file (glob("$name${SAVE_NAME_SUFFIX}*")) {
    unlink($file) or Helper::error("Unable to cleanup after backup. $EADMIN");
  }
}

sub tar_pieces {
  my ($name, $qualifier) = @_;

  chdir $DESTINATION
    or Helper::error("Failed to cd to backup location. $EADMIN");

  my $tstamp = strftime("%Y%m%d%H%M%S", localtime);
  my $filename = "$name-$tstamp-$qualifier.tar.bz2";

  # Paranoia, enforce safe characters in filename.
  Helper::error("Failed to create save backup archive. $EADMIN")
      unless $filename =~ /^[a-z0-9_.-]+$/i;

  # Paranoia, enforce safe characters in name.
  Helper::error("Bogus characters in $name. $EADMIN")
      unless $name =~ /^\w+$/;

  system "tar cvjf $filename $name${SAVE_NAME_SUFFIX}* >/dev/null 2>&1"
    and Helper::error("Archive subcommand failed when archiving "
                          . "save files. $EADMIN");

  $filename
}
