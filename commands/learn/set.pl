#! /usr/bin/perl
use strict;
use warnings;

use File::Spec;
use File::Basename;
use lib File::Spec->catfile(dirname(__FILE__), '../../lib');
use lib File::Spec->catfile(dirname(__FILE__), '../../src');
use LearnDB qw/read_entry num_entries replace_entry insert_entry unquote
               $RTERM_INDEXED $RTERM $RTEXT/;
use LearnDB::Cmd;
use Helper;
use utf8;
use open qw/:std :utf8/;

Helper::eval_or_exit {
  my ($term, $index, $text);
  if ($ARGV[1] =~ /$RTERM_INDEXED $RTEXT/) {
    ($term, $index, $text) = (unquote($1), $2, $3);
  } elsif ($ARGV[1] =~ /$RTERM $RTEXT/) {
    ($term, $text) = (unquote($1), $2);
  }

  $index ||= 1;
  $text = Helper::strip_text($text || '');

  unless ($text =~ /\S/) {
    print "Usage: !learn set TERM[NUM] TEXT";
    exit 1;
  }

  my $old_entry = read_entry($term, $index);
  my $new_entry;
  if ($old_entry) {
    $new_entry = LearnDB::Cmd::replace_entry($term, $index, $text);
  } else {
    $new_entry = LearnDB::Cmd::insert_entry($term, $index, $text);
  }
  print $new_entry;
}
