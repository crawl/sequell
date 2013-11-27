package Henzell::IRC;

use strict;
use warnings;

use lib '..';
use parent 'Bot::BasicBot', 'Henzell::BotService';

use Henzell::Config;
use Data::Dumper;

# Utilities

############################################################################
# IRC bot

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
  print "emoted: ", Dumper($e), "\n" if $ENV{DEBUG_HENZELL};
  $self->_each_service_call('event_emoted', $self->_message_metadata($e));
  return undef;
}

sub chanjoin {
  my ($self, $j) = @_;
  print "chanjoin: ", Dumper($j), "\n" if $ENV{DEBUG_HENZELL};
  $self->_each_service_call('event_chanjoin', $self->_message_metadata($j));
  return undef;
}

sub userquit {
  my ($self, $q) = @_;
  print "quit: ", Dumper($q), "\n" if $ENV{DEBUG_HENZELL};
  $self->_each_service_call('event_userquit', $self->_message_metadata($q));
  return undef;
}

sub chanpart {
  my ($self, $m) = @_;
  print "part: ", Dumper($m), "\n" if $ENV{DEBUG_HENZELL};
  $self->_each_service_call('event_chanpart', $self->_message_metadata($m));
  return undef;
}

sub said {
  my ($self, $m) = @_;
  print "said: ", Dumper($m), "\n" if $ENV{DEBUG_HENZELL};
  $self->_each_service_call('event_said', $self->_message_metadata($m));
  return undef;
}

sub tick {
  my $self = shift;
  $self->_each_service_call('event_tick');
  $self->_call_periodic_actions();
  return 1;
}

sub channel_nicks {
  my ($self, $channel) = @_;
  keys %{$self->channel_data($channel)}
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

1
