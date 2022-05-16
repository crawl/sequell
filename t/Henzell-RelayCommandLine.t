use strict;
use warnings;

use Test::More;
use lib 'lib';

use Henzell::RelayCommandLine;

for my $testcase (
  ["!RELAY -readonly !lg",
    {
      readonly => 1,
      body => '!lg',
      verbatim => '!lg'
    }],
  ["!RELAY -r !lg",
    {
      readonly => 1,
      body => '!lg',
      verbatim => '!lg'
    }],
  ["!RELAY -prefix xyzzy !lg",
    {
      relayprefix => 'xyzzy',
      outprefix => 'xyzzy',
      body => '!lg',
      verbatim => '!lg'
    }],
  ["!RELAY -nick mazda -r !learn add foo baz",
    {
      readonly => 1,
      relaynick => 'mazda',
      nick => 'mazda',
      body => '!learn add foo baz',
      verbatim => '!learn add foo baz'
    }],
  ["!RELAY -n 15 -prefix xyzzy -nick remoteuser !lg",
    {
      relaynick => 'remoteuser',
      relayn => 15,
      nick => 'remoteuser',
      relayprefix => 'xyzzy',
      outprefix => 'xyzzy',
      nlines => 15,
      body => '!lg',
      verbatim => '!lg'
    }],
) {
  is_deeply(
    { Henzell::RelayCommandLine::parse($testcase->[0]) }, $testcase->[1],
    $testcase->[0]);
}

done_testing();
