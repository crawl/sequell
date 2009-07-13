#!/usr/bin/perl
use strict;
use warnings;
do 'commands/learn/helper.pl';

my ($term, $num, $rest);

for ($ARGV[1]) {
  /^([\w! ]+)(\[(\d+)\])\s+(s[^a-z].+)/i || /^([\w! ]+)\s+(s[^a-z].+)/i
    or die "Syntax is: !learn edit TERM[NUM] s/<search>/<repl>/\n";
  ($term, $num, $rest) = ($1, $2, $3);
}

$rest = $num, undef($num) if defined($num) && !defined($rest);

s/^\s+//, s/\s+$// for ($term, $rest);

if (!$num && num_entries($term) > 1) {
  die "Use: !learn edit ${term}[NUM] s/<search>/<repl>/\n";
}
$num ||= 1;

my $text = read_entry($term, $num, 1);

if ($text eq '')
{
  print "I don't have a page labeled $term\[$num] in my learndb.";
  exit;
}

my ($sep) = $rest =~ /^s(.)/;
my $qsep = "\Q$sep";

my ($regex, $replacement, $opts) =
  $rest =~ m{^s$qsep((?:\\$qsep|[^$qsep])*)$qsep((?:\\$qsep|[^$qsep])*)(?:$qsep([ig]*) *)?$} or do
{
  print "Syntax is: !learn edit TERM[NUM] s/REGEX/REPLACE/opts";
  exit;
};
$opts ||= '';

$regex = "^" if $regex eq "";
my $case_sensitive = 1;
my $global = 0;

if (index($opts, "i") >= 0)
{
  $case_sensitive = 0;
}
if (index($opts, "g") >= 0)
{
  $global = 1;
}

if ($case_sensitive)
{
  $regex = eval { qr/$regex/i };
}
else
{
  $regex = eval { qr/$regex/ };
}
print $@ and exit if $@;

my $oldtext = $text;
my $matched = 0;

if ($global)
{
  $matched = $text =~ s/$regex/$replacement/g;
}
else
{
  $matched = $text =~ s/$regex/$replacement/;
}

if (not $matched)
{
  print "No change because the regex failed to match.";
  exit;
}

if ($text eq $oldtext)
{
  print "No change!";
  exit;
}

if (length($text) > 350)
{
  print "New text exceeds the maximum length of 350 characters, aborting.";
  exit;
}

replace_entry($term, $num, $text);
print read_entry($term, $num);
