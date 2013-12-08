package Henzell::IRCStub;

use lib '..';
use parent 'Henzell::BotService';

sub new {
  my ($cls, %opt) = @_;
  bless \%opt, $cls
}

sub nick {
  shift()->bot_nick()
}

sub channel_nicks {
  my ($self, $c) = @_;
  ($self->nick(), 'Anon')
}

sub tick {
  my $self = shift;
  $self->_each_service_call('event_tick');
  $self->_call_periodic_actions();
  return 1;
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

sub say {
  my ($self, %m) = @_;
  my $prefix = '';
  $prefix = "$m{who}: " if $m{channel} eq 'msg';
  $self->write($prefix, $m{body}, "\n");
}

sub emote {
  my ($self, %m) = @_;
  $self->write("/me $m{body}\n");
}

sub notice {
  my ($self, %m) = @_;
  $self->write("/notice $m{who} $m{body}\n");
}

sub write {
  my $self = shift;
  print(@_);
}

1
