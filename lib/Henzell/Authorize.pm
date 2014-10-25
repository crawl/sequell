package Henzell::Authorize;

use strict;
use warnings;

use Henzell::ACL;

sub cmd_permit {
  my ($permission, $nick, $channel) = @_;
  $nick ||= $ENV{HENZELL_ENV_NICK};
  $channel ||= $ENV{HENZELL_ENV_CHANNEL};

  print STDERR "perm:$permission $nick/$channel\n";
  if ($ENV{HENZELL_PROXIED} eq 'y') {
    print "Permission $permission denied: proxying not permitted\n";
    exit 1;
  }

  my $acl = Henzell::ACL::permission_acl($permission);
  return unless $acl;
  unless ($acl->channel_match($channel)) {
    if ($channel eq 'msg') {
      print "Permission $permission denied: PM not authorized\n";
    } else {
      print "Permission $permission denied: channel $channel not authorized\n";
    }
    exit 1;
  }
  my $nick_auth = $acl->nick_match($nick);
  unless ($nick_auth) {
    print "Permission $permission denied: nick $nick not authorized\n";
    exit 1;
  }
  if ($nick_auth eq 'authenticated') {
    if (($ENV{IRC_NICK_AUTHENTICATED} || '') ne 'y') {
      print "[[[AUTHENTICATE: $nick]]]\n";
      exit 1;
    }
  }
}

1
