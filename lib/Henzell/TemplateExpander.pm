package Henzell::TemplateExpander;

use strict;
use warnings;

use IPC::Open2;
use JSON;

sub new {
  my ($cls, %opt) = @_;
  bless { %opt, _opid => 1 }, $cls
}

sub _root {
  $ENV{HENZELL_ROOT} or die "HENZELL_ROOT is not set\n"
}

sub _echo_service {
  my $self = shift;
  if (!$self->{_iecho}) {
    $self->{_echopid} =
      open2(my $in, my $out, 'bundle exec ' . $self->_root() . '/commands/echo-pipe.rb')
        or die "Couldn't spawn echo service\n";
    $self->{_iecho} = $in;
    $self->{_oecho} = $out;
  }
  ($self->{_iecho}, $self->{_oecho})
}

sub _kill_echo_service {
  my $self = shift;
  return unless $self->{_iecho};
  kill(SIGTERM => $self->{_echopid}) if $self->{_echopid};
  close $self->{_iecho};
  close $self->{_oecho};
  delete $self->{_iecho};
  delete $self->{_oecho};
  delete $self->{_echopid};
}

sub _next_opid {
  my $self = shift;
  return $self->{_opid}++;
}

sub expand {
  my ($self, $template, $argline, %opt) = @_;
  my ($in, $out) = $self->_echo_service();
  my $broken_pipe;
  local $SIG{PIPE} = sub { $broken_pipe = 1; };
  my $opid = $self->_next_opid();
  my $m = $opt{irc_msg};
  my $auth = $self->{auth};
  my $authenticated = !$auth || $auth->nick_identified($$m{nick});
  my $effective_channel =
    !$$m{proxied} ? $$m{relaychannel} || $$m{channel} : $$m{channel};
  print $out encode_json({ id => $opid,
                           msg => $template,
                           args => $argline,
                           command_env => {
                             PRIVMSG => $$m{private} || $$m{relaypm},
                             HENZELL_ENV_CHANNEL => $$m{channel},
                             HENZELL_ENV_NICK => $$m{nick},
                             HENZELL_PROXIED => $$m{proxied} ? 'y' : '',
                             IRC_NICK_AUTHENTICATED => $authenticated ? 'y' : ''
                           },
                           env => $opt{env} }), "\n";
  my $res = <$in>;
  if ($broken_pipe || !defined($res)) {
    return $self->retry_expand($template, $argline, %opt);
  }
  my $json = eval {
    decode_json($res);
  };
  undef $json if $@;
  unless ($json) {
    return $self->retry_expand($template, $argline, %opt, real_error => "ERR: Could not parse response: $res");
  }
  unless (($json->{id} || 0) == $opid) {
    return $self->retry_expand($template, $argline, %opt, real_error => "ERR: Template expander desynced");
  }

  delete $self->{retried};
  if ($json && $$json{err}) {
    my $err = $$json{err};
    die $err if $err =~ /^\[{3}/;
    return $err;
  }
  $json && $json->{res}
}

sub retry_expand {
  my ($self, $template, $argline, %opt) = @_;
  if ($self->{retried}) {
    delete $self->{retried};
    return $opt{real_error} || "ERR: Could not expand $template: subprocess exploded\n";
  }

  $self->{retried} = 1;
  $self->_kill_echo_service();
  return $self->expand($template, $argline, %opt);
}

1
