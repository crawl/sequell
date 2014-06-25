package Henzell::ReactorService;

use strict;
use warnings;

use Data::Dumper;
use File::Basename;
use File::Spec;
use Sub::Recursive;

use lib '..';
use lib File::Spec->catfile(dirname(__FILE__), '../src');

use parent qw/Henzell::ServiceBase Henzell::Forkable/;
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
  my ($self, $term, $carp_if_missing, $autocomplete_disabled) = @_;
  if ($autocomplete_disabled) {
    LearnDB::query_entry($term, undef, $carp_if_missing)
  }
  else {
    LearnDB::query_entry_autocorrect($term, undef, $carp_if_missing)
  }
}

sub _db_query {
  my ($self, $m, $query, $bare, $carp_if_missing) = @_;

  my $entry = $self->_lookup_term($query, $carp_if_missing,
                                  $$m{autocomplete_disabled});
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
  my ($terms, $entries, $error) =
    LearnDB::search($term, $terms_only, $entries_only, 'ignore_hidden');
  if ($error) {
    $error =~ s/ at \S+ line \d+[.]\s*$//;
    return $error;
  }
  my $res = describe_results($terms, $entries, 1);
  if (length($res) > 400) {
    $res = describe_results($terms, $entries);
  }
  $res
}

sub db_search {
  my ($self, $m, $chain) = @_;
  return $chain->(undef) unless $m->{said};
  my $body = $$m{body};
  if ($body =~ qr{^\s*([?]/[<>]?)\s*(.*)\s*$}) {
    my ($search_mode, $search_term) = ($1, $2);
    if ($search_term =~ /\S/) {
      my $terms_only = $search_mode eq '?/<';
      my $entries_only = $search_mode eq '?/>';
      $self->{irc}->post_message(
        %$m,
        body => $self->_db_search_result($search_term, $terms_only,
                                         $entries_only));
      return $chain->(1)
    }
  }
  $chain->(undef)
}

sub direct_query {
  my ($self, $m, $chain) = @_;
  return $chain->(undef) unless $m->{said};
  my $body = $$m{body};
  if ($body =~ /^\s*[?]{2}\s*(.+)\s*$/) {
    return $chain->($self->_db_query($m, $1, undef, 'carp-if-missing'));
  }
  $chain->(undef)
}

sub maybe_query {
  my ($self, $m, $chain) = @_;
  return $chain->(undef) unless $m->{said};
  my $body = $$m{body};
  if ($body =~ /^\s*(.+)\s*[?]{2,}\s*$/) {
    return $chain->($self->_db_query($m, $1, 'bare'))
  }
  $chain->(undef)
}

sub indirect_query_event {
  my ($self, $m) = @_;
  my $query = $$m{body} . "??";
  $self->maybe_query({ %$m,
                       body => $query,
                       verbatim => $query,
                       autocomplete_disabled => $$m{autocomplete_disabled},
                       said => 1 },
                     sub {
                       my $result = shift;
                       return 1 if $result;
                       if ($$m{stub}) {
                         $self->{irc}->post_message(%$m, body => $$m{stub});
                         return 1;
                       }
                     });
}

sub behaviour {
  my ($self, $m, $chain) = @_;
  return $chain->(undef) if $$m{nobeh};
  $chain->($self->{beh}->perform_behaviour($m))
}

sub command {
  my ($self, $m, $chain) = @_;
  my $exec = $self->_executor();
  my $command = $exec && $exec->recognized_command_name($m);
  if ($command) {
    $self->async($command,
                 sub {
                   $exec->command_raw_output($m)
                 },
                 sub {
                   my $output = $exec->command_postprocess_output($m, shift());
                   $chain->($self->_respond($m, $output))
                 });
    return;
  }
  $chain->(undef)
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

  my @reactors = @{$self->{reactors}};
  my $i = 0;
  my $chain_next = recursive {
    my $result = shift;
    unless ($result) {
      my $reactor = $reactors[$i++];
      if ($reactor) {
        $reactor->($m, $REC);
      }
    }
  };
  $chain_next->(undef)
}

1
