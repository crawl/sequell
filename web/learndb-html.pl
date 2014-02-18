#!/usr/bin/perl -w

# Script courtesy kilobyte on ##crawl.
# See original at http://angband.pl/crawl/henzell.

use strict;
use warnings;

use CGI;
use HTML::Entities;
use HTTP::Date;
use Unicode::Collate;

use File::Basename;
use File::Spec;
use lib File::Spec->catfile($ENV{HENZELL_ROOT} ||
                              File::Spec->catfile(dirname(__FILE__), '..'),
                            'lib');
use Henzell::SQLLearnDB;
use utf8;
use open qw/:std :utf8/;

my $dbfile = shift() || 'dat/learn.db';
my $db = Henzell::SQLLearnDB->new($dbfile);

my $timestamp = 0;

local $/;

my $title = "##crawl learndb";
my %learndb;
my %redir;
my %link;
my %canonical_term;
my $FULL_REDIRECT_PATTERN = qr/^see \{([^\[\]\}]+(?:\s*\[\s*\d+\s*\])?)\}$/i;

sub hidden_term($) {
  my $term = shift;
  $term =~ /^:\w+:$/ || $term =~ /^~.+/
}

sub canonical_lookup {
  lc(canonical_link(shift))
}

sub canonical_link($)
{
  my $link = shift;
  for ($link) {
    s/\[\s*1\s*\]$//;
    tr/ /_/;
    s/_+\[/[/;
    s/_+/_/g;
    s/^_+//;
    s/_+$//;
  }
  $link
}

sub term_is_link {
  $link{canonical_lookup(shift)}
}

sub term_link {
  my $term = shift;
  $canonical_term{canonical_lookup($term)}
}

sub escape {
  CGI::escapeHTML(shift())
}

sub unescape {
  HTML::Entities::decode_entities(shift())
}

sub addlink($$) {
  my $key = canonical_link($_[0]);
  my $lc_key = lc $key;
  my $dest=canonical_lookup($_[1]);
  ${$redir{$dest}}{$key}=1;
  $link{$lc_key} = 1;
  $canonical_term{$lc_key} = $key;
}

$timestamp = $db->mtime();
$db->each_term(
  sub {
    my $term = shift;
    return if hidden_term($term);
    my @definitions = $db->definitions($term);
    for my $i (1 .. @definitions) {
      my $val = $definitions[$i - 1];
      my $key = $term;
      $key .= "[$i]" if $i > 1;
      if ($val =~ $FULL_REDIRECT_PATTERN) {
        my $dest = $1;
        addlink($key, $dest);
      }
      else {
        addlink($key, $key);
      }
      $learndb{$key}=$val;
    }
  });

print <<EOF;
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<meta name="viewport" content="width=device-width">
<title>$title</title>
<link rel="stylesheet" type="text/css" href="learndb.css">
</head>
<body>
  <h1>${title}</h1>
EOF
print "<p class='note'>Updated on ".time2str($timestamp)."\n";
print "<dl>\n";

sub htmlize($$$)
{
  my ($entry, $multiple, $prefix) = @_;
  for ($entry) {
    $_ = escape($_);
    s{(https?://(?:[!#\$%'*+.,/0-9:;=?A-Z^_a-z|~\-]|&(?!(?:lt|gt);))+)}{<a href="$1">$1</a>}g;
    tr/\x00-\x1f//d;
    s|{([^\[\]\}]+(?:\s*\[\s*\d+\s*\])?)}| term_is_link(unescape($1)) ? "<a href=\"#". escape(term_link(unescape($1))) . "\">$1</a>" : "{$1}"|ge;
  }
  $multiple ? "<li>$prefix<span>$entry</span></li>" : "$prefix$entry"
}

my $collator = Unicode::Collate->new();
for my $key ($collator->sort(keys %learndb))
{
    next if $key =~ /\]$/;

    my $has_multiple = $learndb{"$key\[2]"};
    next if !$has_multiple && $learndb{$key} =~ $FULL_REDIRECT_PATTERN;

    print "<dt>";
    print   "<a name=\"$_\"></a>" for(map(escape($_),
                                          sort keys %{$redir{canonical_lookup($key)}}));

    (my $clean_key = $key) =~ tr{_}{ };
    $clean_key = escape($clean_key);
    print "$clean_key\n";
    print " <dd>";

    print "<ol>" if $has_multiple;
    print htmlize($learndb{$key}, $has_multiple, ''), "\n";
    my $i=1;
    while(exists $learndb{$key."[".++$i."]"})
    {
      my $text = $learndb{$key."[$i]"};
      my $prefix = '';
      $prefix .= "<a name=\"$_\"></a>" for(map(escape($_),
                                               sort keys %{$redir{canonical_lookup($key."[$i]")}}));
      print htmlize($text, $has_multiple, $prefix), "\n";
    }
    print "</ol>" if $has_multiple;
}
print <<EOF;
</dl>
</body>
</html>
EOF
