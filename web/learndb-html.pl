#!/usr/bin/perl -w

# Script courtesy kilobyte on ##crawl.
# See original at http://angband.pl/crawl/henzell.

use HTTP::Date;
use strict;
use warnings;

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
my $FULL_REDIRECT_PATTERN = qr/^see {([a-z0-9_\[\]!?@ -]+)}$/i;

sub addlink($$)
{
    local $_=$_[0];
    my $dest=canonical_link($_[1]);

    #mixed _ and spaces?
    ${$redir{$dest}}{$_}=1;
    $link{$_}=1;

    tr{_}{ };
    ${$redir{$dest}}{$_}=1;
    $link{$_}=1;

    tr{ }{_};
    ${$redir{$dest}}{$_}=1;
    $link{$_}=1;
}

$timestamp = $db->mtime();
$db->each_term(
  sub {
    my $term = shift;
    next if $term eq ':beh:';
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

my $embedded_css = do { local (@ARGV, $/) = 'config/data/learndb.css'; <> };

print <<EOF;
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<title>$title</title>
<style type="text/css">
$embedded_css
</style>
</head>
<body>
  <h1>${title}</h1>
EOF
print "<p class='note'>Updated on ".time2str($timestamp)."\n";
print "<dl>\n";

sub canonical_link($)
{
  my $link = lc(shift);
  $link =~ s/\[1\]$//;
  $link =~ tr/ /_/;
  $link
}

sub htmlize($$$)
{
  my ($entry, $multiple, $prefix) = @_;
  for ($entry) {
    s/&/&amp;/g;
    s/</&lt;/g;
    s/>/&gt;/g;
    s{(http://[!#\$%&'*+,-./0-9:;=?\@A-Z^_a-z|~]+)}{<a href="$1">$1</a>}g;

    my $key;
    tr/\x00-\x1f//d;

    s|{([a-zA-Z0-9_\[\]!?@ -]+)}| $link{canonical_link($1)} ? "<a href=\"#".canonical_link($1)."\">$1</a>" : "{$1}"|ge;
  }
  $multiple ? "<li>$prefix<span>$entry</span></li>" : "$prefix$entry"
}

for my $key (sort keys %learndb)
{
    next if $key =~ /\]$/;

    my $has_multiple = $learndb{"$key\[2]"};
    next if !$has_multiple && $learndb{$key} =~ $FULL_REDIRECT_PATTERN;

    print "<dt>";
    print   "<a name=\"$_\"></a>" for(sort keys %{$redir{$key}});

    (my $clean_key = $key) =~ tr{_}{ };
    print "$clean_key\n";
    print " <dd>";

    print "<ol>" if $has_multiple;
    print htmlize($learndb{$key}, $has_multiple, ''), "\n";
    my $i=1;
    while(exists $learndb{$key."[".++$i."]"})
    {
      my $text = $learndb{$key."[$i]"};
      my $prefix = '';
      $prefix .= "<a name=\"$_\"></a>" for(sort keys %{$redir{$key."[$i]"}});
      print htmlize($text, $has_multiple, $prefix), "\n";
    }
    print "</ol>" if $has_multiple;
}
print <<EOF;
</dl>
</body>
</html>
EOF
