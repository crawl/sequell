#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(setsid); # For daemonization.
use Fcntl qw/:flock SEEK_END/;
use IPC::Open2;

use Henzell::Config qw/%CONFIG %CMD %USER_CMD %PUBLIC_CMD/;
use Henzell::Utils;
use Henzell::IRC;
use Getopt::Long;
use Cwd;

END {
  kill TERM => -$$;
}

my $daemon = 1;
my $irc = 1;
my $config_file = 'rc/henzell.rc';
GetOptions("daemon!" => \$daemon,
           "irc!" => \$irc,
           "rc=s" => \$config_file) or die "Invalid options\n";

$ENV{LC_ALL} = 'en_US.UTF-8';
$ENV{RUBYOPT} = "-rubygems -I" . File::Spec->catfile(getcwd(), 'src');

my $SERVER = 'cao';     # Local server.
my $ALT_SERVER = 'cdo'; # Our 'alternative' server.

# The largest message that Henzell will paginate in PM.
my $MAX_PAGINATE_LENGTH = 3001;

my @stonefiles;
my @logfiles;

# The other bots on the channel that might announce milestones and logfiles.
# When Henzell sees such an announcement, it will fetch logfiles explicitly
# within $sibling_fetch_delay seconds.
my @sibling_bots     = qw/Henzell Gretell Hehfiel Sizzell Sequell/;

# How long after a sibling announcement that Henzell will force-fetch
# logfile records. This should be at least 5s because we don't want a badly-
# behaved bot to cause us to hammer cdo with http requests.
my $sibling_fetch_delay = 10;

my $sibling_logs_need_fetch;

# The most recent explicit fetch of logfile records from sibling servers.
my $sibling_last_fetch_time;

my $seen_dir       = 'dat/seendb';
my %admins         = map {$_ => 1} qw/Eidolos raxvulpine toft
                                      greensnark cbus doy/;

local $SIG{PIPE} = 'IGNORE';
local $SIG{CHLD} = 'IGNORE';
local $| = 1;

load_config($config_file);

my $nickname       = $CONFIG{bot_nick};
my $ircname        = "$nickname the Crawl Bot";
my $ircserver      = $CONFIG{irc_server};
my $port           = $CONFIG{irc_port} || 6667;

my @CHANNELS         = Henzell::Config::array('channels');
my $ANNOUNCE_CHANNEL = $CONFIG{announce_channel};
my $DEV_CHANNEL      = $CONFIG{dev_channel};

my $ANNOUNCEMENTS_FILE = $CONFIG{announcements_file};

my @BORING_UNIQUES = qw/Jessica Ijyb Blork Terence Edmund Psyche
                        Joseph Josephine Harold Norbert Jozef
                        Maud Duane Grum Gastronok Dowan Duvessa
                        Pikel Menkaure Purgy Maurice Yiuf
                        Urug Snorg Eustachio Ribbit Nergalle/;

binmode STDOUT, ':utf8';

Henzell::Utils::lock(verbose => 1,
                     lock_name => $CONFIG{lock_name});

if ($CONFIG{startup_services}) {
  Henzell::Utils::spawn_services($CONFIG{startup_services});
}

# Daemonify. http://www.webreference.com/perl/tutorial/9/3.html
Henzell::Utils::daemonify() if $daemon;

require 'sqllog.pl';

my @loghandles = open_handles(@logfiles);
my @stonehandles = open_handles(@stonefiles);

my $announce_handle = tailed_handle($ANNOUNCEMENTS_FILE);

if ($CONFIG{sql_store}) {
  initialize_sqllog();
  if (@loghandles >= 1) {
    catchup_logfiles();
    catchup_stonefiles();
  }
  # And once again, because creating indexes takes time.
  catchup_stonefiles();
  catchup_logfiles();
}

my $HENZELL;
my $NICK_AUTHENTICATOR = 'NickServ';
my $AUTH_EXPIRY_SECONDS = 60 * 60;
my %AUTHENTICATED_USERS;
my %PENDING_AUTH;

if ($irc) {
  print "Connecting to $ircserver as $nickname, channels: @CHANNELS\n";
  $HENZELL = Henzell->new(nick     => $nickname,
                          server   => $ircserver,
                          port     => $port,
                          name     => $ircname,
                          channels => [ @CHANNELS ],
                          flood    => 1,
                          charset  => "utf-8")
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

sub milestone_is_uniq($) {
  my $g = shift;
  my $type = $$g{type} || '';
  return grep($type, qw/uniq unique/);
}

sub newsworthy
{
  my $g = shift;

  # Milestone type, empty if this is not a milestone.
  my $type = $$g{type} || '';

  my $br_enter = $type eq 'enter' || $type eq 'br.enter';
  my $place_branch = game_place_branch($g);

  return 0 if grep($type eq $_, 'monstrous', 'death', 'br.mid', 'br.exit');

  return 0
    if $br_enter
      && grep($place_branch eq $_, qw/Temple Lair Hive D Orc/);

  if ($type eq 'zig') {
    my ($depth) = ($$g{milestone} || '') =~ /reached level (\d+)/;
    return 0 if $depth < 18 && $$g{xl} >= 27;
  }

  return 0
    if $type =~ /abyss/ and ($g->{god} eq 'Lugonu' || !$g->{god})
      and $g->{cls} eq 'Chaos Knight' and $g->{turn} < 5000;

  # Suppress all Sprint events <300 turns.
  return 0
    if game_type($g) && ($$g{ktyp} || '') ne 'winning'
      && $$g{turn} < 300;

  return 0
    if milestone_is_uniq($g) && grep(index($$g{milestone}, $_) != -1,
                                     @BORING_UNIQUES);

  return 0
    if game_is_sprint($g)
      and milestone_is_uniq($g)
        and (grep {index($g->{milestone}, $_) > -1}
             qw/Ijyb Sigmund Sonja/);

  return 1;
}

sub devworthy
{
  my $g = shift;
  my $type = $$g{type} || '';
  return $type eq 'crash';
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

    if ($CONFIG{announce} && $ANNOUNCE_CHANNEL && $href->{server} eq $CONFIG{host}) {
      my $game_ref = demunge_xlogline($line);
      return unless $game_ref;
      my $newsworthy = newsworthy($game_ref);
      my $devworthy = devworthy($game_ref);

      if ($devworthy) {
        my $ms = milestone_string($game_ref);
        raw_message_post({ channel => $DEV_CHANNEL }, $ms);
      }
      elsif ($newsworthy) {
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

sub make_announcements
{
  return unless $announce_handle;

  my $offset = tell $announce_handle;
  my $line = <$announce_handle>;
  if (!$line || $line !~ /\S.*\n$/) {
    seek($announce_handle, $offset, 0);
    return;
  }

  chomp $line;
  for my $channel ($ANNOUNCE_CHANNEL, $DEV_CHANNEL) {
    if ($channel) {
      raw_message_post({ channel => $channel }, $line);
    }
  }
}

sub suppress_game {
  my $g = shift;
  return 1 unless newsworthy($g);
  return ($g->{sc} <= 2000 &&
    ($g->{ktyp} eq 'quitting' || $g->{ktyp} eq 'leaving'
     || $g->{turn} < 500
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
    return unless $game_ref;
    # If this is a local game, announce it.
    if ($CONFIG{announce} && $ANNOUNCE_CHANNEL
        && $href->{server} eq $CONFIG{host})
    {
      if (!suppress_game($game_ref)) {
        my $output = pretty_print($game_ref);
        $output =~ s/ on \d{4}-\d{2}-\d{2} (?:\d{2}:\d{2}:\d{2})?//;
        unless (contains_banned_word($output)) {
          raw_message_post({ channel => $ANNOUNCE_CHANNEL }, $output);
        }
      }
    }
  }
  1
}

sub sibling_fetch_logs {
  # If we're saving all logfile and milestone entries, update remote
  # logs; else we don't care.
  if ($CONFIG{sql_store}) {
    print "*** Fetching remote logfiles\n" if $ENV{DEBUG_HENZELL};
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

sub nick_is_sibling($) {
  my $nick = shift;
  return ($nick ne $nickname) && scalar(grep($_ eq $nick, @sibling_bots));
}

sub check_sibling_announcements
{
  my ($nick, $verbatim) = @_;
  if (nick_is_sibling($nick)) {
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
  my $output = qx!./commands/message/all_input.pl '$nick' \Q$verbatim\E!;
  if ($output) {
    $HENZELL->say(channel => $$m{channel},
                  who => $$m{who},
                  body => $output);
  }
}

sub raw_message_post {
  my ($m, $output) = @_;

  # Handle emotes (/me does foo)
  if ($output =~ s{^/me }{}) {
    $HENZELL->emote(channel => $$m{channel},
                    who => $$m{who},
                    body => $output);
    return;
  }

  if ($output =~ s{^/notice }{}) {
    $HENZELL->notice(channel => $$m{channel},
                     body => $output);
    return;
  }

  $HENZELL->say(channel => $$m{channel},
                who => $$m{who},
                body => $output);
}

sub respond_with_message {
  my ($m, $output) = @_;
  return unless $output;

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

sub nick_is_authenticator {
  my $nick = shift;
  lc($nick) eq lc($NICK_AUTHENTICATOR)
}

sub authenticate_user {
  my ($user, $msg) = @_;

  print "User $user needs authentication for $$msg{body}\n";
  if ($PENDING_AUTH{$user}) {
    print "Skipping auth for $user: pending auth already\n";
    return;
  }

  $PENDING_AUTH{$user} = $msg;
  $HENZELL->say(channel => 'msg',
                who => $NICK_AUTHENTICATOR,
                body => "ACC $user");
}

sub nick_identified {
  my ($nick, $accept_any_known_auth) = @_;
  my $auth = $AUTHENTICATED_USERS{$nick};
  $auth && ($accept_any_known_auth || $$auth{acc} == 3) &&
    (time() - $$auth{when} < $AUTH_EXPIRY_SECONDS)
}

sub nick_unidentify {
  my $nick = shift;
  delete $AUTHENTICATED_USERS{$nick};
}

sub process_authentication {
  my ($m) = @_;
  print "Processing auth response from $$m{who}: $$m{body}\n";
  my $body = $$m{body};
  return unless $body =~ /^(\S+) ACC (\d+)/;
  my ($nick, $auth) = ($1, $2);
  $AUTHENTICATED_USERS{$nick} = { when => time(), acc => $auth };

  if ($PENDING_AUTH{$nick}) {
    my $msg = $PENDING_AUTH{$nick};
    delete $PENDING_AUTH{$nick};
    if (nick_identified($nick)) {
      $$msg{reproc} = 1;
      process_message($msg);
    }
    else {
      raw_message_post($msg,
                       "Could not authenticate $nick with services for $$msg{body}");
    }
  }
}

sub nick_rule_match {
  my ($rule, $nick) = @_;
  ($$rule{nick} || '') eq $nick
}

sub rule_pattern_match {
  my ($rule, $verbatim) = @_;
  $verbatim =~ qr/$$rule{pattern}/ && $1
}

sub handle_special_command {
  my ($m, $private, $nick, $verbatim) = @_;
  return if $private;
  my $respond_to = $CONFIG{respond_to};
  return unless $respond_to && ref($respond_to) eq 'ARRAY';
  for my $rule (@{$CONFIG{respond_to}}) {
    next unless ref($rule) eq 'HASH';
    next unless nick_rule_match($rule, $nick);
    next unless $$rule{executor} eq 'command';

    my $body = rule_pattern_match($rule, $verbatim);
    next unless $body;
    $$m{body} = $body;
    $$m{proxied} = 1;
    process_command($m);
    return 1;
  }
  undef
}

sub message_metadata {
  my $m = shift;
  my $reprocessed_command = $$m{reproc};
  my $nick = $$m{who};
  my $channel = $$m{channel};
  my $private = $channel eq 'msg';

  my $verbatim = $$m{body};
  my $target = $verbatim;
  $nick     =~ y/'//d;
  my $sibling = nick_is_sibling($nick);

  $target =~ s/^\?[?>]/!learn query /;
  $target =~ s/^!>/!/;

  my $sigils = Henzell::Config::sigils();
  $target =~ s/^([\Q$sigils\E]\S*) *// or undef($target);

  my $command;
  if (defined $target) {
    $command = lc $1;

    $target   =~ s/ .*$//;
    $target   = Henzell::IRC::cleanse_nick($target);
    $target   = $nick unless $target =~ /\S/;
    $target   = Henzell::IRC::cleanse_nick($target);
  }

  if (force_private($verbatim) && !is_always_public($verbatim)) {
    $private = 1;
    $$m{channel} = 'msg';
  }

  {
    m => $m,
    reprocessed_command => $reprocessed_command,
    nick => $nick,
    channel => $channel,
    private => $private,
    verbatim => $verbatim,
    target => $target,
    sibling => $sibling,
    command => $command,
    target => $target,
    proxied => $$m{proxied}
  }
}

sub process_message {
  my ($m) = @_;
  my $meta = message_metadata($m);
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

sub process_command {
  my ($m) = @_;

  my $meta = message_metadata($m);
  my $command = $$meta{command};
  return unless $command;

  my $target = $$meta{target};
  my $nick = $$meta{nick};
  my $verbatim = $$meta{verbatim};
  my $channel = $$meta{channel};
  my $private = $$meta{private};
  my $reprocessed_command = $$meta{reprocessed_command};
  my $proxied = $$meta{proxied};

  if (!$proxied && $command eq '!load' && exists $admins{$nick})
  {
    print "LOAD: $nick: $verbatim\n";
    $HENZELL->say(channel => $channel,
                  who => $$m{who},
                  body => load_commands());
  }
  elsif (Henzell::Config::command_exists($command) &&
         (!$private || !is_always_public($verbatim)))
  {
    # Log all commands to Henzell.
    print "CMD($private): $nick: $verbatim\n";
    $ENV{PRIVMSG} = $private ? 'y' : '';
    $ENV{HENZELL_PROXIED} = $proxied ? 'y' : '';
    $ENV{IRC_NICK_AUTHENTICATED} = nick_identified($nick) ? 'y' : '';
    $ENV{CRAWL_SERVER} = $command =~ /^!/ ? $SERVER : $ALT_SERVER;

    my $processor = $CMD{$command} || $CMD{custom};
    my $output =
      $processor->(pack_args($target, $nick, $verbatim, '', ''));

    if ($output =~ /^\[\[\[AUTHENTICATE: (.*?)\]\]\]/) {
      if ($reprocessed_command || $proxied ||
          nick_identified($nick, 'any_auth')) {
        respond_with_message($m,
              "Cannot authenticate $nick with services, ignoring $verbatim");
      } else {
        authenticate_user($1, $m);
      }
      return;
    }

    respond_with_message($m, $output);
  }
  undef
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
  my $config_file = shift;
  my $loaded = Henzell::Config::read($config_file, \&command_proc);
  process_config();
  $loaded
}

sub load_commands
{
  load_config($config_file);
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

  main::nick_unidentify($$q{who});
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

  if (main::nick_is_authenticator($$m{who})) {
    main::process_authentication($m);
  }
  else {
    main::process_message($m);
  }
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
  main::make_announcements();
  Henzell::Config::load_user_commands();
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

  $self->privmsg($who, $body);
}

1
