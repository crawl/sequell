#!/usr/bin/perl

package LearnDB;

use strict;
use warnings;
use File::Temp qw/tempfile/;
use File::Path qw/mkpath/;
use File::Spec;
use File::Basename;

use lib File::Spec->catfile(dirname(__FILE__), '../../lib');
use Henzell::SQLLearnDB;

use base 'Exporter';

my $DB_PATH = $ENV{LEARNDB} ||
  File::Spec->catfile($ENV{HENZELL_ROOT} || '.', 'dat/learn.db');

my $DB = Henzell::SQLLearnDB->new($DB_PATH);

our @EXPORT_OK = qw/cleanse_term num_entries read_entry print_to_entry
                    del_entry replace_entry swap_entries query_entry
                    check_entry_exists report_error parse_query
                    insert_entry $RTERM $RTERM_INDEXED $RTEXT/;

our $RTERM = qr/([\w!]+)/;
our $RTERM_INDEXED = qr/([\w!]+)\[(\d+)\]/;
our $RTEXT = qr/(.+)/;

our $TERM_MAX_LENGTH = 30;
our $TEXT_MAX_LENGTH = 350;

sub term_exists($;$) {
  my ($term, $num) = @_;
  $DB->definition_exists($term, $num)
}

sub cleanse_term {
  my $term = lc(shift);

  $term =~ y/ /_/;
  $term =~ s/^_+//;
  $term =~ s/_+$//;

  $term =~ y/a-z0-9_!//cd;
  return $term;
}

sub num_entries {
  $DB->definition_count(cleanse_term(shift))
}

sub check_entry_exists($;$) {
  my ($term, $num) = @_;
  if (!$DB->definition_exists($term, $num)) {
    if ($num) {
      die "I don't have a page labeled $term\[$num] in my learndb.";
    }
    else {
      die "I don't have a page labeled $term in my learndb.";
    }
  }
}

sub normalize_index {
  my ($term, $num, $normalize_for_insert) = @_;
  $term = cleanse_term($term);
  $num ||= 1;
  my $total = num_entries($term);
  if ($num < 0) {
    $num += $total + 1;
    $num = 1 if $num <= 0;
  }
  if ($num > $total) {
    $num = $total;
    ++$num if $normalize_for_insert;
  }
  $num
}

sub parse_query {
  my $query = shift;
  my $num;
  $num = $1 if $query =~ s/\[([+-]?\d+|\$)\]? *$//;
  $num ||= 1;
  if ($num eq '$') {
    $num = -1;
  }
  return (cleanse_term($query), $num);
}

sub entry_redirect {
  my $entry = shift;
  return unless $entry && $entry =~ /: see \{(.*)?\}\Z/i;
  parse_query($1)
}

sub query_entry_with_redirects {
  my ($term, $num, $tried) = @_;

  $tried ||= { };
  my $previous_redirecting_entry = '';
  my $res = '';
  for (;;) {
    return $res || $previous_redirecting_entry
      if !defined($term) || $$tried{$term};
    $$tried{$term} = 1;
    $previous_redirecting_entry = $res;
    $res = read_entry($term, $num);

    # Assuming foo[1] redirects to bar[1], pretend that foo[2] ->
    # bar[2], etc. This will behave confusingly if foo contains more
    # entries on foo[2], etc., so don't do that.
    if ((!$res && $num != 1) || $num == -1) {
      my $root_entry = read_entry($term, 1);
      my ($redirect_term, $redirect_num) = entry_redirect($root_entry);
      if ($redirect_num && $redirect_num == 1) {
        $res = query_entry_with_redirects($redirect_term, $num, $tried);
      }
    }

    return $res || $previous_redirecting_entry if $res !~ /: see \{.*\}\Z/i;
    my ($redirect) = $res =~ /\{(.*)\}/;
    ($term, $num) = parse_query($redirect);
  }
}

# Porcelain: parses a query and retrieves an entry, following redirects, etc.
sub query_entry {
  my ($term, $num) = @_;
  return unless $term && $term =~ /\S/;
  unless (defined $num) {
    ($term, $num) = parse_query($term);
  }
  query_entry_with_redirects($term, $num)
}

sub read_entry {
  my ($term, $entry_num, $just_the_entry) = @_;
  $term = cleanse_term($term);
  $entry_num = normalize_index($term, $entry_num);
  my $definition = $DB->definition($term, $entry_num);
  return '' unless defined $definition;
  return $definition if $just_the_entry;

  $term =~ y/_/ /;
  $term = uc $term if $term =~ /^xtahua$/;
  return sprintf '%s[%d/%d]: %s', $term, $entry_num, num_entries($term),
                 $definition;
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

sub insert_entry {
  my ($term, $num, $text) = @_;
  $term = cleanse_term($term);
  check_term_length($term);
  check_text_length($text);

  $DB->add($term, $text, $num);
  return read_entry($term, $num);
}

sub del_entry {
  my $term = cleanse_term(shift);
  my $entry_num = normalize_index(num_entries($term), shift());
  $DB->remove($term, $entry_num);
}

sub replace_entry
{
  my $term = cleanse_term(shift);
  my $entry_num = shift;
  my $new_text = shift;
  $DB->update_value($term, $entry_num, $new_text);
}

sub swap_entries {
  my ($term1, $num1, $term2, $num2) = @_;
  $_ = cleanse_term($_) for ($term1, $term2);
  $num1 = normalize_index($term1, $num1);
  $num2 = normalize_index($term2, $num2);

  my $def1 = $DB->definition($term1, $num1);
  my $def2 = $DB->definition($term2, $num2);
  $DB->update_value($term1, $num1, $def2);
  $DB->update_value($term2, $num2, $def1);
  return 1;
}

sub rename_entry($$) {
  my ($src, $dst) = @_;
  $DB->update_term(cleanse_term($src), cleanse_term($dst));
}

sub move_entry($$$;$) {
  my ($src, $snum, $dst, $dnum) = @_;
  check_term_length($src);
  check_term_length($dst);
  if (!$snum) {
    check_entry_exists($src, 1);
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
