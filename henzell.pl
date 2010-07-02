#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(setsid); # For daemonization.
use Fcntl qw/:flock SEEK_END/;
use IPC::Open2;

use Henzell::Config qw/%CONFIG %CMD %PUBLIC_CMD/;
use Henzell::Utils;
use Getopt::Long;

my $daemon = 1;
my $irc = 1;
GetOptions("daemon!" => \$daemon,
           "irc!" => \$irc) or die "Invalid options\n";

$ENV{LC_ALL} = 'en_US.utf8';

my $SERVER = 'cao';     # Local server.
my $ALT_SERVER = 'cdo'; # Our 'alternative' server.

# The largest message that Henzell will paginate in PM.
my $MAX_PAGINATE_LENGTH = 3001;

my @stonefiles;
my @logfiles;

# The other bots on the channel that might announce milestones and logfiles.
# When Henzell sees such an announcement, it will fetch logfiles explicitly
# within $sibling_fetch_delay seconds.
my @sibling_bots     = qw/Henzell Gretell Hehfiel/;

# How long after a sibling announcement that Henzell will force-fetch
# logfile records. This should be at least 5s because we don't want a badly-
# behaved bot to cause us to hammer cdo with http requests.
my $sibling_fetch_delay = 10;

my $sibling_logs_need_fetch;

# The most recent explicit fetch of logfile records from sibling servers.
my $sibling_last_fetch_time;

my $seen_dir       = '/home/henzell/henzell/dat/seendb';
my %admins         = map {$_ => 1} qw/Eidolos raxvulpine toft
                                      greensnark cbus doy/;

local $SIG{PIPE} = 'IGNORE';
local $SIG{CHLD} = 'IGNORE';

load_config();

my $nickname       = $CONFIG{bot_nick};
my $ircname        = "$nickname the Crawl Bot";
my $ircserver      = 'irc.freenode.org';
my $port           = 6667;

my @CHANNELS         = Henzell::Config::array('channels');
my $ANNOUNCE_CHANNEL = $CONFIG{announce_channel};

binmode STDOUT, ':utf8';

Henzell::Utils::lock(verbose => 1);

# Daemonify. http://www.webreference.com/perl/tutorial/9/3.html
Henzell::Utils::daemonify() if $daemon;

require 'sqllog.pl';

my @loghandles = open_handles(@logfiles);
my @stonehandles = open_handles(@stonefiles);

if ($CONFIG{sql_store}) {
  if (@loghandles >= 1) {
    sql_register_logfiles(map $_->{file}, @loghandles);
    catchup_logfiles();
    sql_register_milestones(map $_->{file}, @stonehandles);
    catchup_stonefiles();
  }
  fixup_db();
  # And once again, because creating indexes takes time.
  catchup_stonefiles();
  catchup_logfiles();
}

my $HENZELL;
if ($irc) {
  $HENZELL = Henzell->new(nick     => $nickname,
                          server   => $ircserver,
                          port     => $port,
                          name     => $ircname,
                          channels => [ @CHANNELS ])
    or die "Unable to create Henzell\n";
  $HENZELL->run();
}
exit 0;

sub catchup_files {
  my ($proc, @files) = @_;
  for my $lhand (@files) {
    my $file = $lhand->{file};
    print "Catching up on records from $file...\n";
    $proc->($lhand)
  }
}

sub catchup_logfiles {
  catchup_files(\&cat_logfile, @loghandles);
}

sub catchup_stonefiles {
  catchup_files(\&cat_stonefile, @stonehandles);
}

sub open_handles
{
  my (@files) = @_;
  my @handles;

  for my $file (@files) {
    my $path = $$file{path};
    open my $handle, '<', $path or do {
      warn "Unable to open $path for reading: $!";
      next;
    };

    seek($handle, 0, SEEK_END); # EOF
    push @handles, { file   => $$file{path},
                     fref   => $file,
                     handle => $handle,
                     pos    => tell($handle),
                     server => $$file{src},
                     src    => $$file{src},
                     alpha  => $$file{alpha} };
  }
  return @handles;
}

sub newsworthy
{
  my $s = shift;

  return 0
    if $s->{type} eq 'enter'
      and grep {$s->{br} eq $_} qw/Temple/;

  return 0
    if $s->{type} =~ /abyss/ and ($s->{god} eq 'Lugonu' || !$s->{god})
      and $s->{cls} eq 'Chaos Knight' and $s->{turn} < 5000;

  return 1;
}

sub check_stonefiles
{
  for my $stone (@stonehandles) {
    1 while check_milestone_file($stone);
  }
}

sub check_milestone_file
{
  my $href = shift;
  my $stonehandle = $href->{handle};
  $href->{pos} = tell($stonehandle);

  my $line = <$stonehandle>;
  # If the line isn't complete, seek back to where we were and wait for it
  # to be done.
  if (!defined($line) || $line !~ /\n$/) {
    seek($stonehandle, $href->{pos}, 0);
    return;
  }
  my $startoffset = $href->{pos};
  $href->{pos} = tell($stonehandle);

  # Clear EOF.
  seek($stonehandle, $href->{pos}, 0);
  if ($line =~ /\S/) {
    # Add milestone to DB.
    add_milestone($href, $startoffset, $line) if $CONFIG{sql_store};

    if ($CONFIG{announce} && $ANNOUNCE_CHANNEL && $href->{server} eq $SERVER) {
      my $game_ref = demunge_xlogline($line);
      my $newsworthy = newsworthy($game_ref);

      if ($newsworthy) {
        my $ms = milestone_string($game_ref);
        unless (contains_banned_word($ms)) {
          raw_message_post({ channel => $ANNOUNCE_CHANNEL }, $ms);
        }
      }
    }
  }
  1
}

sub check_all_logfiles
{
  for my $logh (@loghandles) {
    1 while tail_logfile($logh);
  }
}

sub suppress_game {
  my $g = shift;
  return ($g->{sc} <= 2000 &&
    ($g->{ktyp} eq 'quitting' || $g->{ktyp} eq 'leaving'
     || $g->{turn} < 30
     || ($g->{turn} < 5000 && $g->{place} eq 'Abyss'
         && ($g->{god} eq 'Lugonu' || !$g->{god}) && $g->{cls} eq 'Chaos Knight')));
}

sub tail_logfile
{
  my $href = shift;
  my $loghandle = $href->{handle};

  $href->{pos} = tell($loghandle);
  my $line = <$loghandle>;
  if (!defined($line) || $line !~ /\n$/) {
    seek($loghandle, $href->{pos}, 0);
    return;
  }
  my $startoffset = $href->{pos};
  $href->{pos} = tell($loghandle);

  seek($loghandle, $href->{pos}, 0);
  if ($line =~ /\S/) {
    # Add line to DB.
    add_logline($href, $startoffset, $line) if $CONFIG{sql_store};

    my $game_ref = demunge_xlogline($line);
    # If this is a local game, announce it.
    if ($CONFIG{announce} && $ANNOUNCE_CHANNEL
        && $href->{server} eq $CONFIG{host})
    {
      if (!suppress_game($game_ref)) {
        my $output = pretty_print($game_ref);
        $output =~ s/ on \d{4}-\d{2}-\d{2}//;
        unless (contains_banned_word($output)) {
          raw_message_post({ channel => $ANNOUNCE_CHANNEL }, $output);
        }
      }
    }

    if ($CONFIG{sql_store}) {
      # Link up milestone entries belonging to this player to their
      # corresponding completed games.
      my $sprint = $$href{sprint};
      fixup_milestones($href->{server}, $sprint, $game_ref->{name});
    }
  }
  1
}

sub sibling_fetch_logs {
  # If we're saving all logfile and milestone entries, update remote
  # logs; else we don't care.
  if ($CONFIG{sql_store}) {
    print "*** Fetching remote logfiles\n";
    system "./remote-fetch-logfile >/dev/null 2>&1 &";
  }
  $sibling_last_fetch_time = time();
  $sibling_logs_need_fetch = 0;
}

# This check is not perfect; it will also latch on to whereis responses,
# but that's not a huge issue.
sub is_sibling_announcement {
  for (@_) {
    # | separators are used for @? output.
    return undef if /\|/;

    # Milestone announcements have two sets of parens:
    # Ex: wya (L26 DSAM) reached level 3 of the Tomb of the Ancients. (Tomb:3)
    return 1 if /\(.*?\).*?\(.*?\)/;

    # Logfile announcements have a paren and a turn count.
    return 1 if /\(.*?\).*turn/;
  }
  return undef;
}

sub check_sibling_announcements
{
  my ($nick, $verbatim) = @_;
  if (($nick ne $nickname) && grep($_ eq $nick, @sibling_bots)) {
    if (is_sibling_announcement($verbatim)) {
      $sibling_logs_need_fetch = 1;
    }
  }
}

sub respond_to_any_msg {
  my $m = shift;
  my $nick = $$m{who};
  my $verbatim = $$m{body};
  $nick =~ tr/'//d;
  $verbatim =~ tr/'//d;
  my $output = qx!./commands/message/all_input.pl '$nick' '$verbatim'!;
  if ($output) {
    $HENZELL->say(channel => $$m{channel},
                  who => $$m{who},
                  body => $output);
  }
}

sub raw_message_post {
  my ($m, $output) = @_;

  # Handle emotes (/me does foo)
  if ($output =~ m{^/me }) {
    $output =~ s{^/me }{};
    $HENZELL->emote(channel => $$m{channel},
                    who => $$m{who},
                    body => $output);
    return;
  }

  $HENZELL->say(channel => $$m{channel},
                who => $$m{who},
                body => $output);
}

sub respond_with_message {
  my ($m, $output) = @_;

  my $private = $$m{channel} eq 'msg';

  $output = substr($output, 0, $MAX_PAGINATE_LENGTH) . "..."
    if length($output) > $MAX_PAGINATE_LENGTH;

  if ($private) {
    my $length = length($output);
    my $PAGE = 400;
    for (my $start = 0; $start < $length; $start += $PAGE) {
      if ($length - $start > $PAGE) {
        my $spcpos = rindex($output, ' ', $start + $PAGE - 1);
        if ($spcpos != -1 && $spcpos > $start) {
          raw_message_post($m, substr($output, $start, $spcpos - $start));
          $start = $spcpos + 1 - $PAGE;
          next;
        }
      }
      raw_message_post($m, substr($output, $start, $PAGE));
    }
  }
  else {
    $output = substr($output, 0, 400) . "..." if length($output) > 400;
    raw_message_post($m, $output);
  }
}

sub is_always_public {
  my $command = shift;
  # Every !learn command apart from !learn query has to be public, always.
  return 1 if $command =~ /^!learn/i && $command !~ /^!learn\s+query/i;
  return 1 unless $command =~ /^\W+(\w+)/;
  return $PUBLIC_CMD{lc($1)};
}

sub force_private {
  my $command = shift;
  return $CONFIG{use_pm} && ($command =~ /^!\w/ || $command =~ /^[?]{2}/);
}

sub process_message {
  my ($m) = @_;

  my $nick = $$m{who};
  my $channel = $$m{channel};
  my $private = $channel eq 'msg';

  my $verbatim = $$m{body};
  my $target = $verbatim;
  $nick     =~ y/'//d;

  seen_update($m, "saying '$verbatim' on $channel");
  respond_to_any_msg($m);

  check_sibling_announcements($nick, $verbatim) unless $private;

  $target =~ s/^\?[?>]/!learn query /;
  $target =~ s/^!>/!/;
  $target =~ s/^([!@]\w+) ?// or return;
  my $command = lc $1;

  $target   =~ s/ .*$//;
  $target   =~ y/a-zA-Z0-9_-//cd;
  $target = $nick unless $target =~ /\S/;
  $target   =~ y/a-zA-Z0-9_-//cd;

  if (force_private($verbatim) && !is_always_public($verbatim)) {
    $private = 1;
    $$m{channel} = 'msg';
  }

  if ($command eq '!load' && exists $admins{$nick})
  {
    print "LOAD: $nick: $verbatim\n";
    $HENZELL->say(channel => $channel,
                  who => $$m{who},
                  body => load_commands());
  }
  elsif (exists $CMD{$command} &&
         (!$private || !is_always_public($verbatim)))
  {
    # Log all commands to Henzell.
    print "CMD($private): $nick: $verbatim\n";
    $ENV{PRIVMSG} = $private ? 'y' : '';
    $ENV{CRAWL_SERVER} = $command =~ /^!/ ? $SERVER : $ALT_SERVER;
    my $output =
      $CMD{$command}->(pack_args($target, $nick, $verbatim, '', ''));
    respond_with_message($m, $output);
  }

  undef;
}


sub process_config() {
  @logfiles = @Henzell::Config::LOGS unless @logfiles;
  @stonefiles = @Henzell::Config::MILESTONES unless @stonefiles;
}

sub command_proc
{
  my ($command_dir, $file) = @_;
  return sub {
      my ($args, @args) = @_;
      handle_output(run_command($command_dir, $file, $args, @args));
  };
}

sub load_config
{
  my $loaded = Henzell::Config::read(\&command_proc);
  process_config();
  $loaded
}

sub load_commands
{
  load_config();
}

sub pack_args
{
  return (join " ", map { $_ eq '' ? "''" : "\Q$_"} @_), @_;
}

sub run_command
{
  my ($cdir, $f, $args, @args) = @_;

  my ($out, $in);
  my $pid = open2($out, $in, qq{$cdir/$f $args});
  binmode $out, ':utf8';
  binmode $in, ':utf8';
  print $in join("\n", @args), "\n" if @args;
  close $in;

  my $output = do { local $/; <$out> };
  if ($output =~ /\n!redirect(\S+)/) {
    return $CMD{$1}->($args, @args);
  }
  return $output;
}

sub seen_update {
  my ($e, $doing) = @_;

  return unless $CONFIG{seen_update};
  return if ($$e{channel} || '') eq 'msg' || $$e{who} eq $nickname;

  my $nick = $$e{who};

  $nick =~ y/'//d;
  $doing =~ y/'//d;

  my %seen =
  (
    nick => $nick,
    doing => $doing,
    time => time,
  );
  open my $handle, '>', "$seen_dir/\L$nick\E" or do
  {
    warn "Unable to open $seen_dir/\L$nick\E for writing: $!";
    return;
  };
  binmode $handle, ':utf8';
  print {$handle} join(':',
                       map {$seen{$_} =~ s/:/::/g; "$_=$seen{$_}"}
                       keys %seen),
                  "\n";
}

package Henzell;
use base 'Bot::BasicBot';

sub connected {
  my $self = shift;

  main::load_commands();

  open(my $handle, '<', 'password.txt')
    or warn "Unable to read password.txt: $!";
  my $password = <$handle>;
  close $handle;
  chomp $password;
  $self->say(channel => 'msg',
             who => 'nickserv',
             body => "identify $password");
  return undef;
}

sub emoted {
  my ($self, $e) = @_;
  main::seen_update($e, "acting out $$e{who} $$e{body} on $$e{channel}");
  return undef;
}

sub chanjoin {
  my ($self, $j) = @_;
  main::seen_update($j, "joining the channel");
  return undef;
}

sub userquit {
  my ($self, $q) = @_;

  my $msg = $$q{body};
  my $verb = $$q{verb} || 'quitting';
  main::seen_update($q,
                    $msg? "$verb with message '$msg'"
                    : "$verb without a message");
  return undef;
}

sub chanpart {
  my ($self, $m) = @_;
  $$m{verb} = "parting $$m{channel}";
  $self->userquit($m);
  return undef;
}

sub said {
  my ($self, $m) = @_;
  main::process_message($m);
  return undef;
}

sub tick {
  if ($sibling_logs_need_fetch
      && (!$sibling_last_fetch_time
          || (time() - $sibling_last_fetch_time) > $sibling_fetch_delay))
  {
    main::sibling_fetch_logs();
  }

  main::check_stonefiles();
  main::check_all_logfiles();
  return 1;
}

# Override BasicBot say since it tries to get clever with linebreaks.
sub say {
  # If we're called without an object ref, then we're handling saying
  # stuff from inside a forked subroutine, so we'll freeze it, and toss
  # it out on STDOUT so that POE::Wheel::Run's handler can pick it up.
  if ( !ref( $_[0] ) ) {
    print $_[0] . "\n";
    return 1;
  }

  # Otherwise, this is a standard object method

  my $self = shift;
  my $args;
  if (ref($_[0])) {
    $args = shift;
  } else {
    my %args = @_;
    $args = \%args;
  }

  my $body = $args->{body};

  # add the "Foo: bar" at the start
  $body = "$args->{who}: $body"
    if ( $args->{channel} ne "msg" and $args->{address} );

  # work out who we're going to send the message to
  my $who = ( $args->{channel} eq "msg" ) ? $args->{who} : $args->{channel};

  unless ( $who && $body ) {
    print STDERR "Can't PRIVMSG without target and body\n";
    print STDERR " called from ".([caller]->[0])." line ".([caller]->[2])."\n";
    print STDERR " who = '$who'\n body = '$body'\n";
    return;
  }

  my ($ewho, $ebody) = $self->charset_encode($who, $body);
  $self->privmsg($ewho, $ebody);
}
