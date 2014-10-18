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
  my $prefix = $m{outprefix} || '';
  my $PAGE = 400;
  if (length($prefix) > $PAGE / 2) {
    $prefix = substr($prefix, 0, int($PAGE / 2));
  }
  $PAGE -= length($prefix);

  my $output = $m{body} || '';
  return unless (defined($output) && $output =~ /\S/) || $prefix;

  my $private = $m{channel} eq 'msg';
  my $nlines = $m{nlines} || ($private ? -1 : 1);

  $output = substr($output, 0, $MAX_PAGINATE_LENGTH) . "..."
    if length($output) > $MAX_PAGINATE_LENGTH;

  if ($nlines == -1 || $nlines > 1) {
    my $length = length($output);
    my $line = 0;
    for (my $start = 0; $start < $length && ($nlines == -1 || $line < $nlines);
         $start += $PAGE, $line++)
    {
      if ($length - $start > $PAGE) {
        my $spcpos = rindex($output, ' ', $start + $PAGE - 1);
        if ($spcpos != -1 && $spcpos > $start) {
          $self->say(%m,
                     body => ($prefix .
                                substr($output, $start, $spcpos - $start)));
          $start = $spcpos + 1 - $PAGE;
          next;
        }
      }
      $self->say(%m, body => ($prefix . substr($output, $start, $PAGE)));
    }
  }
  else {
    $output = substr($output, 0, $PAGE) . "..." if length($output) > $PAGE;
    $self->say(%m, body => ($prefix . $output));
  }
}

sub post_message {
  my ($self, %m) = @_;
  my $output = $m{body};
  $output = "$output" if defined($output);

  return unless (defined($output) && $output =~ /\S/) || $m{outprefix};

  # Handle emotes (/me does foo)
  if (!$m{outprefix} && $output =~ s{^/me }{}) {
    $self->emote(%m, body => $output);
    return;
  }

  $self->say_paged(%m, body => $output);
}

sub _message_metadata {
  my ($self, $m) = @_;
  my $nick = $$m{who};
  my $channel = $$m{channel};
  my $private = $channel eq 'msg';

  my $verbatim = $$m{raw_body} || $$m{body};
  $nick     =~ y/'//d;
  my $sibling = $self->nick_is_sibling($nick);

  +{
    %$m,
    nick => $nick,
    channel => $channel,
    private => $private,
    verbatim => $verbatim,
    body => $verbatim,
    sibling => $sibling,
    authenticator => $self->nick_is_authenticator($nick),
    self => lc($$m{who}) eq lc($self->nick())
  }
}

1
