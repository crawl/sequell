package Henzell::ReactorService;

use strict;
use warnings;

use Data::Dumper;
use File::Basename;
use File::Spec;

use lib '..';
use lib File::Spec->catfile(dirname(__FILE__), '../src');

use parent 'Henzell::ServiceBase';
use Henzell::LearnDBBehaviour;
use Henzell::LearnDBLookup;

use LearnDB;

my $BEHAVIOUR_KEY = ':beh:';

sub new {
  my ($cls, %opt) = @_;
  my $self = bless { behaviour_key => $BEHAVIOUR_KEY, %opt }, $cls;
  $self->{reactors} = $self->_reactors();
  $self->{dblookup} =
    Henzell::LearnDBLookup->new(executor => $self->_executor());
  $self->{beh} = Henzell::LearnDBBehaviour->new(irc => $opt{irc},
                                                dblookup => $self->_lookup());
  $self->subscribe_event('learndb_service', 'indirect_query',
                         sub {
                           my ($alias, $event, @args) = @_;
                           $self->indirect_query_event(@args);
                         });
  $self
}

sub _lookup {
  shift()->{dblookup}
}

sub _executor {
  shift()->{executor}
}

sub _need_refresh {
  my $self = shift;
  !$self->{refreshed} || LearnDB::mtime() >= $self->{refreshed}
}

sub _refresh {
  my $self = shift;
  return unless $self->_need_refresh();
  my @beh = $self->_read_behaviours();
  $self->{beh}->set_behaviours(@beh);
  $self->{refreshed} = time();
}

sub _read_behaviours {
  my $self = shift;
  LearnDB::read_entries($self->{behaviour_key})
}

sub _reactors {
  my $self = shift;
  [
    sub {
      $self->behaviour(@_)
    },

    sub {
      $self->direct_query(@_)
    },

    sub {
      $self->maybe_query(@_)
    },

    sub {
      $self->command(@_)
    }
  ]
}

sub _expand {
  my ($self, $m, $msg, $bare) = @_;
  return undef unless $msg;
  return $msg->err() if $msg->err();
  $self->_lookup()->resolve($m, $msg->entry(), $bare, '', $self->{beh}->env($m))
}

sub _db_query {
  my ($self, $m, $query, $bare, $carp_if_missing) = @_;
  my $msg =
    $self->_expand($m,
                   LearnDB::query_entry($query, undef, $carp_if_missing),
                   $bare);
  if (defined $msg && $msg =~ /\S/) {
    $msg = "$$m{prefix}$msg" if $$m{prefix};
    $self->{irc}->post_message(%$m, body => $msg);
    1
  }
}

sub direct_query {
  my ($self, $m) = @_;
  return unless $m->{said};
  my $body = $$m{body};
  if ($body =~ /^\s*[?]{2}\s*(.+)\s*$/) {
    $self->_db_query($m, $1, undef, 'carp-if-missing');
  }
}

sub maybe_query {
  my ($self, $m) = @_;
  return unless $m->{said};
  my $body = $$m{body};
  if ($body =~ /^\s*(.+)\s*[?]{2,}\s*$/) {
    $self->_db_query($m, $1, 'bare');
  }
}

sub indirect_query_event {
  my ($self, $m) = @_;
  my $query = $$m{body} . "??";
  if ($self->maybe_query({ %$m,
                           body => $query,
                           verbatim => $query,
                           said => 1 })) {
    return 1;
  }
  if ($$m{stub}) {
    $self->{irc}->post_message(%$m, body => $$m{stub});
    return 1;
  }
  undef
}

sub behaviour {
  my ($self, $m) = @_;
  $self->{beh}->perform_behaviour($m)
}

sub command {
  my ($self, $m) = @_;
  $self->_respond($m, $self->_executor()->execute_command($m))
}

sub _respond {
  my ($self, $m, $res) = @_;
  if (defined($res) && $res =~ /\S/) {
    s/^\s+//, s/\s+$// for $res;
    if ($res ne '') {
      $res = "$$m{prefix}$res" if $$m{prefix};
      $self->{irc}->post_message(%$m, body => $res);
      return 1
    }
  }
  return undef
}

sub event_said {
  my ($self, $m) = @_;
  $self->react({ %$m, event => 'said', said => 1 });
}

sub event_emoted {
  my ($self, $m) = @_;
  $self->react({ %$m, event => 'emoted', emoted => 1,
                 body => "/me $$m{body}" });
}

sub event_chanjoin {
  my ($self, $m) = @_;
  $self->react({ %$m, event => 'chanjoin', chanjoin => 1,
                 body => "/join $$m{body}" });
}

sub event_chanpart {
  my ($self, $m) = @_;
  $self->react({ %$m, event => 'chanpart', chanpart => 1,
                 body => "/part $$m{body}" });
}

sub event_userquit {
  my ($self, $m) = @_;
  $self->react({ %$m, event => 'userquit', userquit => 1,
                 body => "/quit $$m{body}" });
}

sub react {
  my ($self, $m) = @_;
  return if $$m{self} || $$m{authenticator} || $$m{sibling} || !$$m{body};
  $self->_refresh();
  for my $reactor (@{$self->{reactors}}) {
    last if $reactor->($m);
  }
}

1
