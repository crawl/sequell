#!/usr/bin/perl

# use strict;
# use warnings;

my $nick = shift;
my $baseURL = "http://crawl.akrasiac.org/rawdata/";
my $localPath = "/var/www/crawl/rawdata/";

my $localDump = $localPath . $nick . "/" . $nick . ".txt";

do 'commands/helper.pl';
help("Gives an URL to the specified users crawl configuration file.");

if (-e $localDump)	{ print $baseURL . $nick . "/" . $nick . ".txt"; }
else			{ print "User does not exist.\n"; }
