#!/usr/bin/perl

use strict;
use warnings;

my $nick = shift;
my $baseURL = "http://crawl.akrasiac.org/rcfiles/";
my $localPath = "/var/www/crawl/rcfiles/";
my $rcsuffix = ".nethackrc";

my $localRC = $localPath . $nick . ".nethackrc";

do 'commands/helper.pl';
help("Gives an URL to the specified users crawl configuration file.");

sub rcpath {
  "$localPath$_[0]$rcsuffix"
}

sub showRC {
  -e(rcpath($_[0])) && do {
    print "$baseURL$_[0]$rcsuffix\n";
    1;
  };
}

sub globRC {
  my $nick = shift;
  my @allrc = glob("${localPath}*$rcsuffix");
  for my $m (@allrc) {
    my ($name) = $m =~ /^\Q$localPath\E(.*)\Q$rcsuffix\E$/;
    if (lc($name) eq lc($nick)) {
      showRC($name) and exit(0);
    }
  }
  die "$nick doesn't even exist!\n";
}

showRC($nick) || globRC($nick)
