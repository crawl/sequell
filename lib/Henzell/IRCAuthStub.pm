package Henzell::IRCAuthStub;

use List::Util qw/first/;

=item Henzell::IRCAuthStub->new('identified_nick1', 'identified_nick2');

A test stub for Henzell::IRCAuth that treats the initial list of identified users
as having been authenticated with NickServ.

=cut

sub new {
  my ($cls, @identified_users) = @_;
  bless { identified_users => \@identified_users }, $cls
}

sub nick_is_authenticator {
  undef
}

sub nick_identified {
  my ($self, $nick) = @_;
  first { $_ eq $nick } @{$self->{identified_users}}
}

1
