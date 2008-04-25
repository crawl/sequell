#!/usr/bin/perl
use strict;
use warnings;
do 'commands/learn/helper.pl';

$ARGV[1] =~ /^([\w!]+) (.+)/ or do
{
  print "Syntax is: !learn add TERM TEXT";
  exit;
};

my ($term, $text) = (cleanse_term($1), $2);

if (length($term) > 30)
{
  print "Term name exceeds the maximum length of 30 characters, aborting.";
  exit;
}

if (length($text) > 350)
{
  print "Entry text exceeds the maximum length of 350 characters, aborting.";
  exit;
}

print add_entry($term, $text, $ARGV[0]);

