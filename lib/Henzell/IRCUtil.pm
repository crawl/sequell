package Henzell::IRCUtil;

use strict;
use warnings;

our $NICK_AUTHENTICATOR = 'NickServ';

sub cleanse_nick {
  my $nick = shift;
  $nick =~ tr{'<>/}{}d;
  lc($nick)
}

1
