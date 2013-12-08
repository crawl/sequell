package Henzell::Bus;

use strict;
use warnings;

sub new {
  my ($cls, %opt) = @_;
  bless { %opt, subscribers => { } }, $cls
}

sub subscribe {
  my ($self, $identity, $alias, $event, $action) = @_;
  push @{$self->{subscribers}{$alias}}, [$event, $action, $identity];
}

sub unsubscribe {
  my ($self, $identity, $alias) = @_;
  my @subscribers = grep($_->[2] != $identity, $self->subscribers($alias));
  if (@subscribers) {
    $self->{subscribers}{$alias} = [@subscribers];
  } else {
    delete $self->{subscribers}{$alias};
  }
}

sub subscribers {
  my ($self, $alias) = @_;
  @{$self->{subscribers}{$alias}}
}

sub event_match {
  my ($self, $event, $event_pattern) = @_;
  $event eq $event_pattern || $event_pattern eq '*'
}

sub publish {
  my ($self, $alias, $event, @args) = @_;

  my @subscribers = $self->subscribers($alias);
  for my $subscriber (@subscribers) {
    if ($self->event_match($event, $subscriber->[0])) {
      $subscriber->[1]->($alias, $event, @args);
    }
  }
}

1
