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
      $self->db_search(@_)
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

sub _lookup_term {
  my ($self, $term, $carp_if_missing) = @_;
  LearnDB::query_entry_autocorrect($term, undef, $carp_if_missing)
}

sub _db_query {
  my ($self, $m, $query, $bare, $carp_if_missing) = @_;

  my $entry = $self->_lookup_term($query, $carp_if_missing);
  my $msg = $self->_expand($m, $entry, $bare);
  if (defined $msg && $msg =~ /\S/) {
    $msg = "$$m{prefix}$msg" if $$m{prefix};
    $self->{irc}->post_message(%$m, body => $msg);
    1
  }
}

sub describe_results {
  my ($terms, $entries, $verbose) = @_;
  if (!@$terms && !@$entries) {
    return "No matches.";
  }

  my $prefix = "Matching ";
  my @pieces;
  if (@$terms) {
    push @pieces,
      "terms (" . @$terms . "): " . join(", ", @$terms);
  }
  if (@$entries) {
    push @pieces,
      "entries (". @$entries . "): " .
        join(" | ", map($_->desc($verbose ? 2 : 0),
                        @$entries));
  }
  $prefix . join("; ", @pieces)
}

sub _db_search_result {
  my ($self, $term, $terms_only, $entries_only) = @_;
  my ($terms, $entries) = LearnDB::search($term, $terms_only, $entries_only);
  my $res = describe_results($terms, $entries, 1);
  if (length($res) > 400) {
    $res = describe_results($terms, $entries);
  }
  $res
}

sub db_search {
  my ($self, $m) = @_;
  return unless $m->{said};
  my $body = $$m{body};
  if ($body =~ qr{^\s*([?]/[<>]?)\s*(.*)\s*$}) {
    my ($search_mode, $search_term) = ($1, $2);
    my $terms_only = $search_mode eq '?/<';
    my $entries_only = $search_mode eq '?/>';
    $self->{irc}->post_message(
      %$m,
      body => $self->_db_search_result($search_term, $terms_only,
                                       $entries_only));
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
  return undef if $$m{nobeh};
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

sub event_tick {
  my $self = shift;
  $self->_executor()->event_tick();
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

  return if $self->_executor()->irc_auth_process($m);
  return if $$m{self} || $$m{authenticator} || $$m{sibling} || !$$m{body};
  $self->_refresh();
  if ($$m{body} =~ s/^\\\\//) {
    $$m{nobeh} = 1;
    $$m{verbatim} =~ s/^\\\\//;
    s/^\s+//, s/\s+$// for ($$m{body}, $$m{verbatim});
  }
  for my $reactor (@{$self->{reactors}}) {
    last if $reactor->($m);
  }
}

1
