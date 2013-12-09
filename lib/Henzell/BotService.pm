# Plumbing to manage services attached to a bot.
package Henzell::BotService;

use lib '..';
use Henzell::Config qw/%CONFIG %CMD %USER_CMD %PUBLIC_CMD/;
use Henzell::IRCUtil;

# The largest message the bot will paginate in PM.
my $MAX_PAGINATE_LENGTH = 3001;

sub bot_nick {
  Henzell::Config::get()->{bot_nick}
}

sub sibling_bots {
  Henzell::Config::array('sibling_bots')
}

sub nick_is_sibling {
  my ($self, $nick) = @_;
  return unless $nick;
  $nick = lc $nick;

  ($nick ne lc($self->nick())) &&
    scalar(grep($_ eq $nick, map(lc, sibling_bots())))
}

sub nick_is_authenticator {
  my ($self, $nick) = @_;
  lc($nick) eq lc($Henzell::IRCUtil::NICK_AUTHENTICATOR)
}

sub configure_services {
  my ($self, %opt) = @_;
  $self->{henzell_services} = $opt{services} || [];
  $self->{henzell_periodic_actions} = $opt{periodic_actions} || [];
  $self
}

sub _services {
  @{shift()->{henzell_services}}
}

sub _periodic_actions {
  @{shift()->{henzell_periodic_actions}}
}

sub _each_service_call {
  my ($self, $action, @args) = @_;
  for my $service ($self->_services()) {
    if ($service->can($action)) {
      $service->$action(@args);
    }
  }
}

sub _call_periodic_actions {
  my ($self, @args) = @_;
  for my $periodic_action ($self->_periodic_actions()) {
    $periodic_action->(@args);
  }
}

############################################################################
# IRC interface to services

sub say_paged {
  my ($self, %m) = @_;
  my $output = $m{body};
  return unless defined($output) && $output =~ /\S/;

  my $private = $m{channel} eq 'msg';

  $output = substr($output, 0, $MAX_PAGINATE_LENGTH) . "..."
    if length($output) > $MAX_PAGINATE_LENGTH;

  if ($private) {
    my $length = length($output);
    my $PAGE = 400;
    for (my $start = 0; $start < $length; $start += $PAGE) {
      if ($length - $start > $PAGE) {
        my $spcpos = rindex($output, ' ', $start + $PAGE - 1);
        if ($spcpos != -1 && $spcpos > $start) {
          $self->say(%m, body => substr($output, $start, $spcpos - $start));
          $start = $spcpos + 1 - $PAGE;
          next;
        }
      }
      $self->say(%m, body => substr($output, $start, $PAGE));
    }
  }
  else {
    $output = substr($output, 0, 400) . "..." if length($output) > 400;
    $self->say(%m, body => $output);
  }
}

sub post_message {
  my ($self, %m) = @_;
  my $output = $m{body};
  $output = "$output" if defined($output);

  return unless defined($output) && $output =~ /\S/;

  # Handle emotes (/me does foo)
  if ($output =~ s{^/me }{}) {
    $self->emote(%m, body => $output);
    return;
  }

  # if ($output =~ s{^/notice }{}) {
  #   $self->notice(%m, body => $output);
  #   return;
  # }

  $self->say_paged(%m, body => $output);
}

sub _message_metadata {
  my ($self, $m) = @_;
  my $nick = $$m{who};
  my $channel = $$m{channel};
  my $private = $channel eq 'msg';

  my $verbatim = $$m{body};
  $nick     =~ y/'//d;
  my $sibling = $self->nick_is_sibling($nick);

  +{
    %$m,
    nick => $nick,
    channel => $channel,
    private => $private,
    verbatim => $verbatim,
    sibling => $sibling,
    authenticator => $self->nick_is_authenticator($nick),
    self => lc($$m{who}) eq lc($self->nick())
  }
}

1
