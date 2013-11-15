package Henzell::AnnounceService;

use strict;
use warnings;

use POE;

sub new {
  my ($cls, %opt) = @_;
  my $self = bless \%opt, $cls;
  $self->_activate();
  $self
}

sub _game_event {
  my ($self, $event) = @_;
  if ($self->game_is_local($event)) {
  }
}

sub game_is_local {
  my ($self, $game) = @_;
  $game->{server} eq $self->{host}
}

sub _activate {
  my $self = shift;
  POE::Session->create(
    inline_states => {
      _start => sub {
        $_[KERNEL]->alias_set('announce_service');
      },
      game_event => sub {
        $self->_game_event($_[ARG0]);
      }
    } );
}

1
