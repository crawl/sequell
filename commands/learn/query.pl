#!/usr/bin/perl
use strict;
use warnings;

use lib 'commands/learn';
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
else
{
  my $entries_ref = entries_for($term);

  if (@$entries_ref == 0)
  {
    print "I really don't have a page labeled $term in my learndb.";
    exit;
  }

  if (0 && @$entries_ref > 2)
  {
    print "That term is too large to send to the channel, sorry.";
    exit;
  }

  print $entries_ref->[1];
}

sub fetch_entry {
  my ($term, $num) = @_;
  my %tried;
  my $previous_redirecting_entry = '';
  my $res = '';
  for (;;) {
    return $res || $previous_redirecting_entry
      if !defined($term) || $tried{$term};
    $tried{$term} = 1;
    $previous_redirecting_entry = $res;
    $res = read_entry($term, $num);
    return $res || $previous_redirecting_entry if $res !~ /: see \{.*\}\Z/i;
    my ($redirect) = $res =~ /\{(.*)\}/;
    ($term, $num) = parse_query($redirect);
  }
}

sub parse_query {
  my $query = shift;
  my $num;
  $num = $1 if $query =~ s/\[(\d+)\] *$//;
  $num ||= 1;
  return (cleanse_term($query), $num);
}
