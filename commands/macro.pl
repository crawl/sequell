#!/usr/bin/perl

# use strict;
# use warnings;

my $nick = shift;
my $baseURL = "http://crawl.akrasiac.org/rcfiles/";
my $localPath = "/var/www/crawl/rcfiles/";

my $localRC = $localPath . $nick . ".nethackrc";

do 'commands/helper.pl';
help("Gives an URL to the specified users crawl configuration file.");

if(-e $localRC)	{ print $baseURL . $nick . ".macro\n"; }
else			{ print "User does not exist.\n"; }
