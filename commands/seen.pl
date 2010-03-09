#!/usr/bin/perl
use strict;
use warnings;
do 'commands/message/helper.pl';

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

my $seen_dir = '/home/henzell/henzell/dat/seendb';

if (lc($ARGV[0]) eq lc($ARGV[1]))
{
  print "Sorry $ARGV[1], that person is dead.\n";
  exit;
}

my $target = cleanse_nick($ARGV[0]);
my $nick = $ARGV[1];

open my $handle, '<', "$seen_dir/$target" or do
{
  print "Sorry $nick, I haven't seen $ARGV[0].\n";
  exit;
};
binmode $handle, ':utf8';

my $line = <$handle>;
my $seen_ref = demunge_xlogline($line);

printf 'I last saw %s at %s UTC (%s ago) %s.%s',
       $seen_ref->{nick},
       scalar gmtime($seen_ref->{time}),
       serialize_time(time - $seen_ref->{time}, 1),
       $seen_ref->{doing},
       "\n";
