#!/usr/bin/perl
use strict;
use warnings;

use File::Spec;
use File::Basename;
use lib File::Spec->catfile(dirname(__FILE__), '../../lib');
use lib File::Spec->catfile(dirname(__FILE__), '../../src');
use LearnDB qw/cleanse_term num_entries read_entry del_entry/;
use Helper;
use utf8;
use open qw/:std :utf8/;

Helper::forbid_private();

$ARGV[1] =~ y/ /_/;
$ARGV[1] =~ /^([^\[\]]+)(?:\[\s*([+-]?\d+|\$)\s*\]?)?/ or do
{
  print "Syntax is: !learn delete TERM[NUM] (you may omit [NUM] if TERM has only one entry)";
  exit;
};

my ($term, $num) = (cleanse_term($1), $2);
$num = -1 if $num && $num eq '$';

my $entries = num_entries($term);
$num ||= 1 if $entries == 1;

if ($entries == 0)
{
  print "That's easy, $term doesn't even exist!";
}
elsif (!defined($num)) # if $entries == 1, $num is defined
{
  print "$term has $entries entries, you can only delete one at a time.";
}
elsif ($num > $entries)
{
  print "$term has only $entries entr".($entries==1?"y":"ies").".";
}
else
{
  my $text = read_entry($term, $num);
  del_entry($term, $num);
  print "Deleted $text";
}
