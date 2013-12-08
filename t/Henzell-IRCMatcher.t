use strict;
use warnings;

use Test::More;
use lib 'lib';

use Henzell::IRCMatcher;

sub default_context {
  +{ BOT => 'Sequell' }
}

sub ircm {
  my ($pattern, $ctx) = @_;
  Henzell::IRCMatcher->parse($pattern, $ctx || default_context())
}

sub match {
  my ($pattern, $msg) = @_;
  ircm($pattern)->match(msg($msg))
}

sub msg {
  my ($msg, $channel, $who) = @_;
  +{ channel => $channel || '##crawl',
     body => $msg,
     who => $who || 'greensnark' }
}

ok(match('\$rc>>>', '$rc'), 'Matches $rc');
ok(match('\$rc>>>', '$rc greensnark'), 'Matches $rc');
ok(match('\$rc>>>', '$rc greensnark')->{env}{after} eq ' greensnark');
ok(!match('\$rc>>>', 'c $rc'));

ok(!match('caramba', 'Ai caramba'), "Match must be full-string");
ok(match('.*caramba', 'Ai caramba'));
ok(match('.*caramba', 'Ai caramba'));

done_testing();
