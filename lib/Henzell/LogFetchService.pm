package Henzell::LogFetchService;

use strict;
use warnings;

use IO::Handle;
use Cwd;

# How long after a sibling announcement that Henzell will force-fetch
# logfile records.
my $sibling_fetch_delay = 1;

# Fetch logs at least once in so many seconds, even if we haven't seen
# any siblings speak.
my $longest_logfetch_pause = 120;

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
  $self->_request_fetch();
  $self->{last_fetch_time} = time();
  $self->{fetch_logs} = 0;
}

sub _request_fetch {
  my $self = shift;
  my $slave = $self->_slave();
  print $slave "fetch\n";
  $slave->flush;
}

sub _slave {
  my $self = shift;
  $self->{_slave} ||= $self->_new_slave_fd()
}

sub _new_slave_fd {
  my $self = shift;
  my $pwd = getcwd();
  my $cmd = "seqdb --log log/seqdb.log isync";
  open my $outf, '|-', $cmd or die "Can't open pipe to `$cmd`: $!\n";
  $outf->autoflush(1);
  $outf
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
