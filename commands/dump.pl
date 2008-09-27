#!/usr/bin/perl

# use strict;
# use warnings;

use lib 'commands';
use Helper;

Helper::help("Gives an URL to the specified user's last character dump.");

my $nick = Helper::nick_alias(shift);
my $baseURL = "http://crawl.akrasiac.org/rawdata/";
my $localPath = "/var/www/crawl/rawdata/";

if (!-d "$localPath/$nick") {
  my $lcnick = lc $nick;
  my @dirs = grep(lc($_) eq $lcnick,
                  map(substr($_, length($localPath)), glob("$localPath/*")));
  unless (@dirs) {
    print "$nick doesn't even exist!\n";
    exit 1;
  }
  $nick = $dirs[0];
}

my $localDump = $localPath . $nick . "/" . $nick . ".txt";


if (-e $localDump)	{ print $baseURL . $nick . "/" . $nick . ".txt"; }
else			{ print "Dump for $nick does not exist.\n"; }
