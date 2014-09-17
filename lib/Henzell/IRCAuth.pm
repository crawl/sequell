package Henzell::IRCAuth;

use strict;
use warnings;

use lib '..';
use Henzell::IRCUtil;

my $AUTH_EXPIRY_SECONDS = 10;

sub new {
  my ($cls, %opt) = @_;
  bless { auth_service => $Henzell::IRCUtil::NICK_AUTHENTICATOR,
          auth_expiry_seconds => $AUTH_EXPIRY_SECONDS,
          %opt,
          cmd => { }, authenticated_users => { } }, $cls
}

sub auth_service {
  shift()->{auth_service}
}

sub pending_auth {
  my ($self, $user) = @_;
  $self->{cmd}{$user}
}

sub nick_is_authenticator {
  my ($self, $nick) = @_;
  lc($nick) eq lc($self->auth_service())
}

sub authorized_commands {
  my ($self, $auth_response) = @_;

  my $responder = $$auth_response{who};
  my $body = $$auth_response{body};

  if (!$self->nick_is_authenticator($responder)) {
    print "[ERROR] Got auth response from $responder, expected $self->auth_service()\n";
    return ();
  }

  print "Processing auth response from $responder: $body\n";
  unless ($body =~ /^(\S+) ACC (\d+)/) {
    print "Unexpected response from $responder: $body\n";
    return;
  }
  my ($nick, $auth) = ($1, $2);
  $self->{authenticated_users}{$nick} = { when => time(), acc => $auth };

  if ($self->pending_auth($nick)) {
    my $msgs = $self->{cmd}{$nick};
    delete $self->{cmd}{$nick};

    if ($self->nick_identified($nick)) {
      print "Returning " . scalar(@$msgs) . " commands for $nick\n";
      return map { +{%$_, reprocessed_command => 1} } @$msgs;
    }
    else {
      if (@$msgs) {
        my $m = $msgs->[0];
        print "Announcing that $nick is unauthorized for $$m{body}\n";
        $self->{irc}->post_message(%$m,
            body => "Could not authenticate $nick with services for $$m{body}"
        );
      } else {
        print "No queued commands for $nick\n";
      }
    }
  } else {
    print "No pending auth requests for $nick\n";
  }
}

sub authenticate_user {
  my ($self, $user, $m) = @_;
  print "User $user needs authentication for $$m{body}\n";

  my $pending_auth = $self->pending_auth($user);
  push @{$self->{cmd}{$user}}, $m;

  if ($pending_auth) {
    print "Skipping auth for $user: pending auth already\n";
    return;
  }

  print "Asking $self->auth_service() to authenticate $user\n";
  $self->{irc}->post_message(channel => 'msg',
                             who => $self->auth_service(),
                             body => "ACC $user");
}

sub nick_unidentify {
  my ($self, $nick) = @_;
  delete $self->{authenticated_users}{$nick};
}

sub nick_identified {
  my ($self, $nick, $did_attempt_authenticate) = @_;
  my $auth = $self->{authenticated_users}{$nick};
  $auth && ($did_attempt_authenticate || $$auth{acc} == 3) &&
    (time() - $$auth{when} < $self->{auth_expiry_seconds})
}

1
