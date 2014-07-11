#!/usr/bin/perl
use strict;
use warnings;

use lib 'src';
use lib 'lib';
use Seen;
use Helper;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

my $seen_dir = 'dat/seendb';

if (lc($ARGV[0]) eq lc($ARGV[1]))
{
  print "Sorry $ARGV[1], that person is dead.\n";
  exit;
}

my $target = $ARGV[0];
my $nick = $ARGV[1];

my $seen_ref = Seen::seen($target);
if (!$seen_ref) {
  print "Sorry $nick, I haven't seen $target.\n";
  exit;
};

printf 'I last saw %s at %s UTC (%s ago) %s.%s',
       $seen_ref->{nick},
       scalar gmtime($seen_ref->{time}),
       Helper::serialize_time(time - $seen_ref->{time}, 1),
       $seen_ref->{doing},
       "\n";
