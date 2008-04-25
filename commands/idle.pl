#!/usr/bin/perl
use strict;
use warnings;
do 'commands/helper.pl';

help("Displays how long it's been since the player typed something into Crawl.");
my $nick = shift;
my $games_ref = games_for($nick);

if (@$games_ref == 0)
{
  print "No games for $nick.\n";
  exit;
}

$nick = $games_ref->[0]{name};
my @ttyrecs = sort </home/crawl/chroot/dgldir/ttyrec/$nick/*.ttyrec>;
my $latest = $ttyrecs[-1];
my $timestamp = (stat $latest)[9];

printf '%s was last active on crawl.akrasiac.org at %s UTC (%s ago).%s',
       $nick,
       scalar gmtime($timestamp),
       serialize_time(time() - $timestamp, 1),
       "\n";

