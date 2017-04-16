# Henzell IRC command responder.
# Expects an irc interface conforming to Bot::BasicBot to be provided.

package Henzell::CommandService;

use strict;
use warnings;

use File::Basename;
use File::Spec;
use Data::Dumper;

use lib '..';
use lib File::Spec->catfile(dirname(__FILE__), '../src');

use parent qw/Henzell::ServiceBase Henzell::Forkable/;

use Henzell::Config qw/%CONFIG %CMD %USER_CMD %PUBLIC_CMD/;
use Henzell::Game;
use Henzell::IRCUtil;
use IPC::Open2;
use Helper;

my %admins         = map {$_ => 1} qw/Eidolos raxvulpine toft
                                      greensnark cbus doy/;

sub new {
  my ($cls, %opt) = @_;
  my $irc = $opt{irc} or die "No irc provider\n";
  my $auth = $opt{auth};
  my $config_file = $opt{config};
  my $self = bless {
    %opt,
    config_file => $config_file,
    backlog => []
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

sub event_chanpart {
  my ($self, $part) = @_;
  $self->event_userquit($part);
}

sub event_tick {
  my $self = shift;
  $self->_load_commands();
  my $queued_command = shift(@{$self->{backlog}});
  if ($queued_command) {
    print "Replaying queued command: $$queued_command{body}\n";
    $self->_irc_said($queued_command);
  }
}

########################################################################

sub irc_auth_process {
  my ($self, $m) = @_;
  my $auth = $self->_auth();
  if ($auth && $auth->nick_is_authenticator($$m{who})) {
    $self->_process_auth_response($m);
    return 1;
  }
  undef
}

sub _irc_said {
  my ($self, $m) = @_;
  if (!$self->irc_auth_process($m)) {
    $self->_process_command($m);
  }
}

sub _process_auth_response {
  my ($self, $auth_response) = @_;

  my @authorized_commands = $self->_auth()->authorized_commands($auth_response);
  push @{$self->{backlog}}, @authorized_commands;
}

sub _message_metadata {
  my ($self, $m) = @_;
  return $m if $m->{command_metadata};

  my $verbatim = $$m{body};
  my $target = $verbatim;
  my $sigils = Henzell::Config::sigils();
  my $private = $$m{private};

  $target =~ s/^([\Q$sigils\E]\S*) *// or undef($target);
  my $command;

  if (defined $target) {
    $command = lc $1;

    $target   =~ s/ .*$//;
    $target   = Henzell::IRCUtil::cleanse_nick($target);
    $target   = $$m{nick} unless $target =~ /\S/;
    $target   = Henzell::IRCUtil::cleanse_nick($target);
  }

  if ($self->force_private($verbatim)) {
    $private = 1;
    $$m{channel} = 'msg';
  }

  +{ %$m,
      private => $private,
      target => $target,
      command => $command,
      command_metadata => 1
   }
}

sub force_private {
  my ($self, $command) = @_;
  return $CONFIG{use_pm} && ($command =~ /^!\w/ || $command =~ /^[?]{2}/);
}

sub _pack_args {
  return (join " ", map { $_ eq '' ? "''" : "\Q$_"} @_), @_;
}

sub _process_command {
  my ($self, $m) = @_;
  my $res = $self->execute_command($m);
  return unless defined($res);
  $self->{irc}->post_message(%$m, body => $res);
}

sub recognized_command_name {
  my ($self, $m) = @_;
  $m = $self->_message_metadata($m);
  my $command = $$m{command};
  $command &&
    Henzell::Config::command_exists($command) &&
        $command
}

sub recognized_command {
  my ($self, $m) = @_;
  $self->recognized_command_name($m)
}

sub env_map {
  my ($self, $m) = @_;
  my %env = (%$m, bot => $self->{irc}->nick());
  my %envmap = map(("HENZELL_ENV_\U$_" => $env{$_}), keys(%env));
  if (!$env{relayed} && !$env{proxied} && $env{relaychannel}) {
    $envmap{HENZELL_ENV_CHANNEL} = $env{relaychannel};
  }
  %envmap
}

sub _command_processor {
  my ($self, $command) = @_;
  $CMD{$command} || $CMD{custom}
}

sub command_raw_output {
  my ($self, $m) = @_;
  $m = $self->_message_metadata($m);

  my $command = $$m{command};
  return undef unless $command;

  my $auth = $self->_auth();
  my $target = $$m{target};
  my $nick = $$m{nick};
  my $verbatim = $$m{verbatim};
  my $channel = $$m{channel};
  my $private = $$m{private} || $$m{relaypm} || '';
  my $proxied = $$m{proxied};

  if (!$proxied && $command eq '!load' && exists $admins{$nick})
  {
    print "LOAD: $nick: $verbatim\n";
    return $self->_load_commands();
  }

  if ($self->recognized_command($m))
  {
    # Log all commands to Henzell.
    print STDERR "CMD($private): $nick: $verbatim (target: $target)\n";
    local $ENV{PRIVMSG} = $private ? 'y' : '';
    local $ENV{HENZELL_PROXIED} = $proxied ? 'y' : '';
    local $ENV{IRC_NICK_AUTHENTICATED} =
      !$auth || $auth->nick_identified($nick) ? 'y' : '';

    my %env_map = $self->env_map($m);
    local @ENV{keys %env_map} = values %env_map;

    my $processor = $self->_command_processor($command);
    my $output =
      $processor->(_pack_args($target, $nick, $verbatim, '', ''));
    $output = '' unless defined $output;
    return $output;
  }
  undef
}

sub execute_command {
  my ($self, $m) = @_;
  $self->command_postprocess_output( $m, $self->command_raw_output($m) )
}

sub command_postprocess_output {
  my ($self, $m, $output) = @_;
  return $output unless defined $output;

  my $reprocessed_command = $$m{reprocessed_command};
  my $auth = $self->_auth();
  my $proxied = $$m{proxied};
  my $verbatim = $$m{verbatim};
  my $nick = $$m{nick};

  if ($output =~ /^\[\[\[AUTHENTICATE: (.*?)\]\]\]/) {
    if ($reprocessed_command || $proxied ||
          !$auth || $auth->nick_identified($nick, 'attempted_auth')) {
      return "Cannot authenticate $nick with services, ignoring $verbatim";
    } else {
      $auth->authenticate_user($1, $m);
    }
    return undef;
  }

  if ($output =~ /^\[\[\[LEARNDB: (.*?):::(.*?):::(.*)\]\]\]$/) {
    my ($prefix, $query, $stub) = ($1, $2, $3);
    $self->publish_event('learndb_service', 'indirect_query',
                         { %$m,
                           body => $query,
                           verbatim => $query,
                           prefix => $prefix,
                           stub => $stub,
                           autocomplete_disabled => 1 });
    $output = '';
  }

  return $output;
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
    Henzell::Config::load_user_commands();
    $loaded
  }
}

sub _command_proc_generator {
  my $self = shift;
  sub {
    my ($command_dir, $file) = @_;
    return sub {
      my ($args, @args) = @_;
      $self->handle_output(
        $self->_run_command($command_dir, $file, $args, @args))
    };
  }
}

sub handle_output {
  my ($self, $output, $full_output) = @_;

  return unless $output =~ /\S/s;
  if ($output =~ s/^\n//)
  {
    $output =~ s/^([^ ]* )://;
    my $pre = defined($1) ? $1 : '';
    $output =~ s/:([^:]*)$//;
    my $post = defined($1) ? $1 : '';

    return '' unless $output =~ /\S/;
    my $g = Helper::demunge_xlogline($output);
    my $str = exists($g->{milestone}) ?
      Henzell::Game::milestone_string($g, 1) :
      Henzell::Game::game_string($g);
    $output = $pre . $str . $post;
  }

  $output =~ s/\n.*//s unless $full_output;
  chomp $output;
  return $output;
}

sub _run_command {
  my ($self, $cdir, $f, $args, @args) = @_;

  my ($out, $in);
  my $pid = open2($out, $in, qq{$cdir/$f $args});
  binmode $out, ':utf8';
  binmode $in, ':utf8';
  print $in join("\n", @args), "\n" if @args;
  close $in;

  my $output = do { local $/; <$out> };
  if ($output =~ /\n!redirect(\S+)/) {
    return $self->_command_processor($1)->($args, @args);
  }
  return $output;
}

1
