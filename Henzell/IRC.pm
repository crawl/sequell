package Henzell::IRC;

use base 'Bot::BasicBot';

use strict;
use warnings;

use lib '..';
use Henzell::Config;

# Utilities

sub cleanse_nick {
  my $nick = shift;
  $nick =~ tr{'<>/}{}d;
  lc($nick)
}

sub bot_nick {
  Henzell::Config::get()->{bot_nick}
}

sub sibling_bots {
  Henzell::Config::array('sibling_bots')
}

############################################################################
# IRC bot

sub nick_is_sibling {
  my ($self, $nick) = @_;
  return unless $nick;
  $nick = lc $nick;

  ($nick ne lc($self->nick())) &&
    scalar(grep($_ eq $nick, map(lc, sibling_bots())))
}

sub configure_services {
  my ($self, %opt) = @_;
  $self->{henzell_services} = $opt{services} || [];
  $self->{henzell_periodic_actions} = $opt{periodic_actions} || [];
  $self
}

sub connected {
  my $self = shift;

  $self->_each_service_call('event_connected');
  open(my $handle, '<', 'password.txt')
    or do {
      warn "Unable to read password.txt: $!";
      return undef;
    };
  my $password = <$handle>;
  close $handle;
  chomp $password;
  $self->say(channel => 'msg',
             who => 'nickserv',
             body => "identify $password");
  return undef;
}

sub emoted {
  my ($self, $e) = @_;
  $self->_each_service_call('event_emoted', $self->_message_metadata($e));
  return undef;
}

sub chanjoin {
  my ($self, $j) = @_;
  $self->_each_service_call('event_chanjoin', $self->_message_metadata($j));
  return undef;
}

sub userquit {
  my ($self, $q) = @_;
  $self->_each_service_call('event_userquit', $self->_message_metadata($q));
  return undef;
}

sub chanpart {
  my ($self, $m) = @_;
  $self->_each_service_call('event_chanpart', $self->_message_metadata($m));
  return undef;
}

sub said {
  my ($self, $m) = @_;
  $self->_each_service_call('event_said', $self->_message_metadata($m));
  return undef;
}

sub tick {
  my $self = shift;
  $self->_each_service_call('event_tick');
  $self->_call_periodic_actions();
  return 1;
}

# Override BasicBot say since it tries to get clever with linebreaks.
sub say {
  # If we're called without an object ref, then we're handling saying
  # stuff from inside a forked subroutine, so we'll freeze it, and toss
  # it out on STDOUT so that POE::Wheel::Run's handler can pick it up.
  if ( !ref( $_[0] ) ) {
    print $_[0] . "\n";
    return 1;
  }

  # Otherwise, this is a standard object method

  my $self = shift;
  my $args;
  if (ref($_[0])) {
    $args = shift;
  } else {
    my %args = @_;
    $args = \%args;
  }

  my $body = $args->{body};

  # add the "Foo: bar" at the start
  $body = "$args->{who}: $body"
    if ( $args->{channel} ne "msg" and $args->{address} );

  # work out who we're going to send the message to
  my $who = ( $args->{channel} eq "msg" ) ? $args->{who} : $args->{channel};

  unless ( $who && defined($body) ) {
    print STDERR "Can't PRIVMSG without target and body\n";
    print STDERR " called from ".([caller]->[0])." line ".([caller]->[2])."\n";
    print STDERR " who = '$who'\n body = '$body'\n";
    return;
  }

  $self->privmsg($who, $body);
}


sub _message_metadata {
  my ($self, $m) = @_;
  my $nick = $$m{who};
  my $channel = $$m{channel};
  my $private = $channel eq 'msg';

  my $verbatim = $$m{body};
  $nick     =~ y/'//d;
  my $sibling = $self->nick_is_sibling($nick);

  if (force_private($verbatim) && !is_always_public($verbatim)) {
    $private = 1;
    $$m{channel} = 'msg';
  }

  {
    m => $m,
    who => $$m{who},
    body => $$m{body},
    nick => $nick,
    channel => $channel,
    private => $private,
    verbatim => $verbatim,
    sibling => $sibling
  }
}

sub _services {
  @{shift()->{henzell_services}}
}

sub _periodic_actions {
  @{shift()->{henzell_periodic_actions}}
}

sub _each_service_call {
  my ($self, $action, @args) = @_;
  for my $service ($self->_services()) {
    if ($service->can($action)) {
      $service->$action(@args);
    }
  }
}

sub _call_periodic_actions {
  my ($self, @args) = @_;
  for my $periodic_action ($self->_periodic_actions()) {
    $periodic_action->(@args);
  }
}

1
