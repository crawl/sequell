#!/usr/bin/perl
use strict;
use warnings;

use lib "commands/learn";
use LearnDB;

my ($term, $num) = parse_query($ARGV[1]);
exit 0 unless $term =~ /\S/;
if (defined $num)
{
  my $entry = fetch_entry($term, $num); #read_entry($term, $num);
  if ($entry eq '')
  {
	if ($num == 1) {
	  print "I don't have a page labeled $term in my learndb.";
	}
	else {
	  print "I don't have a page labeled $term\[$num] in my learndb.";
	}
  }
  else
  {
    print $entry;
  }
}

sub entry_redirect($)
{
  my $entry = shift;
  return unless $entry && $entry =~ /: see \{(.*)?\}\Z/i;
  parse_query($1)
}

sub fetch_entry {
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
        $res = fetch_entry($redirect_term, $num, $tried);
      }
    }

    return $res || $previous_redirecting_entry if $res !~ /: see \{.*\}\Z/i;
    my ($redirect) = $res =~ /\{(.*)\}/;
    ($term, $num) = parse_query($redirect);
  }
}

sub parse_query {
  my $query = shift;
  my $num;
  $num = $1 if $query =~ s/\[(-?\d+|\$)\]? *$//;
  $num ||= 1;
  if ($num eq '$') {
    $num = -1;
  }
  return (cleanse_term($query), $num);
}
