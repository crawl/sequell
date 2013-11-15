# Henzell IRC command responder.
# Expects an irc interface conforming to Bot::BasicBot to be provided.

package Henzell::CommandService;

use strict;
use warnings;

use lib '..';
use Henzell::Config qw/%CONFIG %CMD %USER_CMD %PUBLIC_CMD/;

sub new {
  my ($cls, %opt) = @_;
  my $irc = $opt{irc} or die "No irc provider\n";
  my $auth = $opt{auth};
  my $config_file = $opt{config};
  my $self = bless {
    irc => $irc,
    auth => $auth,
    config_file => $config_file
   }, $cls;
  $self->_load_commands();
  $self
}

sub event_emoted {
  my ($self, $q) = @_;
  my %act = %$q;
  $act{emote} = 1;
  $self->_irc_said(\%act)
}

sub event_said {
  my ($self, $m) = @_;
  $self->_irc_said($m);
}

sub event_userquit {
  my ($self, $q) = @_;
  my $auth = $self->_auth();
  if ($auth) {
    $auth->nick_unidentify($q->{who});
  }
}

sub event_tick {
  my $self = shift;
  $self->_load_commands();
}

########################################################################

sub _irc_said {
  my ($self, $m) = @_;
  my $auth = $self->auth();
  if ($auth && $auth->nick_is_authenticator($$m{who})) {
    $self->_process_auth_response();
  } else {
    $self->_process_message($m);
  }
}

sub _process_message {
  my ($self, $m) = @_;
  my $meta = $self->_message_metadata($m);
  unless ($$meta{sibling} || $$meta{reprocessed_command}) {
    seen_update($m, "saying '$$meta{verbatim}' on $$meta{channel}");
    respond_to_any_msg($m);
  }

  unless ($$meta{private} || $$meta{reprocessed_command}) {
    check_sibling_announcements($$meta{nick}, $$meta{verbatim});
  }

  if (!$$meta{reprocessed_command} &&
      handle_special_command($m, $$meta{private}, $$meta{nick},
                             $$meta{verbatim}))
  {
    return;
  }
  return if $$meta{sibling};
  process_command($m);

}

sub _auth {
  shift()->{auth}
}

sub _irc {
  shift()->{irc}
}

sub _config {
  shift()->{config_file}
}

sub _load_commands {
  my $self = shift;
  if ($self->_config()) {
    my $loaded = Henzell::Config::read($self->_config(),
                                       $self->_command_proc_generator());
    $loaded
  }
}

sub _command_proc_generator {
  my $self = shift;
  sub {
    my ($command_dir, $file) = @_;
    return sub {
      my ($args, @args) = @_;
      $self->_handle_output(
        $self->_run_command($command_dir, $file, $args, @args));
    };
  }
}

1
