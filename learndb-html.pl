#!/usr/bin/perl -w

# Script courtesy kilobyte on ##crawl.
# See original at http://angband.pl/crawl/henzell.

use HTTP::Date;
use strict;
use warnings;

my $timestamp = 0;

local $/;

my $title = "Henzell's learndb";
my %learndb;
my %redir;
my %link;
my $FULL_REDIRECT_PATTERN = qr/^see {([a-z0-9_\[\]!?@ -]+)}$/i;

sub addlink($$)
{
    local $_=$_[0];
    my $dest=$_[1];

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

for(split /\n/, `find dat/learndb/ -type f ! -name '*.html*'`)
{
    open F, "<$_" or die "Can't read [$_]\n";
    if (m:learndb/([a-z0-9_-]+)/(\d+):)
    {
        my $key = $1;
        $key.="[$2]" if $2!='1';
        my $val = <F>;
        if ($val =~ $FULL_REDIRECT_PATTERN)
        {
            addlink($key, $1);
        }
        else
        {
            addlink($key, $key);
        }
        $learndb{$key}=$val;
    }
    close F;

    my @st;
    $timestamp = $st[10] if @st=stat $_ and $st[10]>$timestamp;
}

my $embedded_css = do { local (@ARGV, $/) = 'learndb.css'; <> };

print <<EOF;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
        "http://www.w3.org/TR/html4/strict.dtd">
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

    s|{([a-zA-Z0-9_\[\]!?@ -]+)}| $link{canonical_link("$1")} ? "<a href=\"#".canonical_link($key)."\">$1</a>" : "{$1}"|ge;
  }
  $multiple ? "<li>$prefix<span>$entry</span></li>" : "$prefix$entry"
}

for my $key (sort keys %learndb)
{
    next if $key =~ /\]$/;

    my $has_multiple = $learndb{"$key\[2]"};
    next if !$has_multiple && $learndb{$key} =~ $FULL_REDIRECT_PATTERN;

    print "<dt>";
    print   "<a name=\"$key\"></a>" for(sort keys %{$redir{$key}});

    (my $clean_key = $key) =~ tr{_}{ };
    print "$clean_key\n";
    print " <dd>";

    print "<ol>" if $has_multiple;
    print htmlize($learndb{$key}, $has_multiple, ''), "\n";
    my $i=1;
    while($learndb{$key."[".++$i."]"})
    {
      my $text = $learndb{$key."[$i]"};
      my $prefix = '';
      $prefix .= "<a name=\"$key\"></a>" for(sort keys %{$redir{$key."[$i]"}});
      print htmlize($text, $has_multiple, $prefix), "\n";
    }
    print "</ol>" if $has_multiple;
}
print <<EOF;
</dl>
</body>
</html>
EOF
