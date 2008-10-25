#!/usr/bin/perl -w

# Script courtesy kilobyte on ##crawl.
# See original at http://angband.pl/crawl/henzell.

use HTTP::Date;
use strict;
use warnings;

my $timestamp = 0;

local $/;

my %learndb;
my %redir;
my %link;

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
        if ($val=~/^see {([a-z0-9_\[\]!?@ -]+)}$/i)
        {
            addlink($key, $1);
        }
        else
        {
            addlink($key, $key);
            $learndb{$key}=$val;
        }
    }
    close F;

    my @st;
    $timestamp = $st[10] if @st=stat $_ and $st[10]>$timestamp;
}
print <<EOF;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
        "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<title>Henzell's learndb</title>
<style type="text/css">
dt { display:run-in; border-top:black ridge; margin-top:0.5em; font-weight:bold; }
dd { display:block; }
.note { font-size:smaller; }
</style>
</head>
<body>
EOF
print "<p class=note>Updated on ".time2str($timestamp)."\n";
print "<dl>\n";

sub htmlize($)
{
    local ($_)=@_;
    s/&/&amp;/g;
    s/</&lt;/g;
    s/>/&gt;/g;
    s{(http://[!#\$%&'*+,-./0-9:;=?\@A-Z^_a-z|~]+)}{<a href="$1">$1</a>}g;

    my $key;
    s|{([a-zA-Z0-9_\[\]!?@ -]+)}| $link{"\L$1"} ? "<a href=\"#".($key="\L$1",$key=~tr{ }{_},$key)."\">$1</a>" : "{$1}"|ge;
    return $_;
}

for(sort keys %learndb)
{
    next if /\]$/;
    print "<dt>";
    print   "<a name=\"$_\"></a>" for(sort keys %{$redir{$_}});
    my $key = $_;
    $key=~tr{_}{ };
    print "$key\n";
    print " <dd>", htmlize($learndb{$_}), "\n";
    my $i=1;
    while($learndb{$_."[".++$i."]"})
    {
        print "  <p>";
        print "<a name=\"$_\"></a>" for(sort keys %{$redir{$_."[$i]"}});
        print htmlize($learndb{$_."[$i]"}), "\n";
    }
}
print <<EOF;
</dl>
</body>
</html>
EOF
