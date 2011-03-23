#!/usr/bin/perl

use strict;
use warnings;
use lib 'commands';
use Helper;

use File::Glob qw/:globally :nocase/;

my $nick = Helper::nick_alias(shift);
my $baseURL = "http://crawl.akrasiac.org/rcfiles/";
my $localPath = "/var/www/crawl/rcfiles";

my $rcsuffix_glob = ".*rc";

help("Gives an URL to the specified user's crawl configuration file.");

sub rc_match($$) {
  my ($dir, $user) = @_;
  foreach my $file ("$dir/$user.rc", "$dir/$user.crawlrc") {
    return $file if -f $file;
  }
  glob("$dir/$user$rcsuffix_glob")
}

sub find_user_rc($) {
  my $user = shift;
  my @subdirs = (grep(-d, glob("${localPath}/crawl-*")), $localPath);
  # [ds] Weird behaviour of map here on perl 5.8: not using the temp
  # $f breaks
  my @files = map { my $f = rc_match($_, $user); $f } @subdirs;
  @files = grep(-f, grep($_, @files));
  @files = sort { -M($a) <=> -M($b) } @files;
  $files[0]
}

sub show_rc_url($) {
  my $rc = shift;
  unless ($rc) {
    print "Can't find rc for $nick.\n";
    return;
  }

  my ($subpath) = $rc =~ m{^$localPath/*(.*)};
  print "$baseURL$subpath\n";
}

show_rc_url(find_user_rc($nick));
