package Henzell::LogFetchService;

use strict;
use warnings;

# How long after a sibling announcement that Henzell will force-fetch
# logfile records. This should be at least 5s because we don't want a badly-
# behaved bot to cause us to hammer cdo with http requests.
my $sibling_fetch_delay = 10;

# Fetch logs at least once in so many seconds, even if we haven't seen
# any siblings speak.
my $longest_logfetch_pause = 15 * 60;

sub new {
  my ($cls, %opt) = @_;
  bless \%opt, $cls
}

sub nick_is_sibling {
  my ($self, $nick) = @_;
  return ($nick ne $self->{irc}->bot_nick()) &&
    scalar(grep($_ eq $nick, @{$self->{siblings}}));
}

sub sibling_announcement {
  my ($self, $message) = @_;
  for ($message) {
    # | separators are used for @? output.
    return undef if /\|/;

    # Milestone announcements have two sets of parens:
    # Ex: wya (L26 DSAM) reached level 3 of the Tomb of the Ancients. (Tomb:3)
    return 1 if /\(.*?\).*?\(.*?\)/;

    # Logfile announcements have a paren and a turn count.
    return 1 if /\(.*?\).*turn/;
  }
  undef
}

sub _need_logfetch {
  my $self = shift;
  return 1 unless $self->{last_fetch_time};
  return 1 if $self->{fetch_logs} &&
              (time() - $self->{last_fetch_time}) > $sibling_fetch_delay;

  (time() - $self->{last_fetch_time}) > $longest_logfetch_pause
}

sub _fetch_logs {
  my $self = shift;
  print "*** Fetching remote logfiles\n" if $ENV{DEBUG_HENZELL};
  system "./remote-fetch-logfile >/dev/null 2>&1 &";
  $self->{last_fetch_time} = time();
  $self->{fetch_logs} = 0;
}

sub event_said {
  my ($self, $m) = @_;
  if ($self->nick_is_sibling($$m{who}) &&
        $self->sibling_announcement($$m{body}))
  {
    $self->{fetch_logs} = 1;
  }
}

sub event_tick {
  my $self = shift;
  if ($self->_need_logfetch()) {
    $self->_fetch_logs();
  }
}

1
