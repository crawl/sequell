#! /usr/bin/env perl

use strict;
use warnings;
no warnings 'uninitialized';

use lib 'lib';
use Henzell::ACL;

my ($perm, $nick, $chan) = @ARGV;
if ($perm && $perm eq '-') {
  chomp(my $line = <STDIN>);
  ($perm, $nick, $chan) = split ' ', $line;
}

$nick ||= '';
$chan ||= '';
unless ($perm && $nick ne '' && $chan ne '') {
  exit 1;
}

if ($ENV{HENZELL_READONLY} eq 'y') {
  print "DENY:read-only\n";
  exit 1;
}

if ($ENV{HENZELL_PROXIED} eq 'y') {
  print "DENY:proxying not permitted\n";
  exit 1;
}

my $nick_authenticated = $ENV{IRC_NICK_AUTHENTICATED} eq 'y';
my $acl = Henzell::ACL::permission_acl($perm);
unless ($acl) {
  print "any\n";
  exit 0;
}

my $channel_auth = $acl->channel_match($chan);
if (!$channel_auth) {
  if ($chan eq 'msg') {
    print "DENY:PM not authorized\n";
  } else {
    print "DENY:channel $chan not authorized\n";
  }
  exit 1;
}

my $nick_auth = $acl->nick_match($nick);
if (!$nick_auth) {
  print "DENY:nick $nick not authorized\n";
  exit 1;
}

print "$nick_auth\n";
exit 0;
