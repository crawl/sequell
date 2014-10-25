package Henzell::ACL::Rule;

use strict;
use warnings;

sub new {
  my ($cls, $groups, $aclname, @entries) = @_;

  my $name = lc(strip_acl_name($aclname));
  my $exact = $name !~ /\*$/;
  $name =~ s/[*.]$//;

  my $match = $exact ? $name : qr/^\Q$name/;
  my $matcher = $exact ?
    sub { lc(shift()) eq $name } : sub { lc(shift()) =~ /^\Q$name/ };

  my $rule = compile_acl_entries($groups, @entries);
  bless {
    name => $name,
    exact => $exact,
    matcher => $matcher,
    rule => $rule
  }, $cls
}

sub invert_matcher {
  my ($deny, $matcher) = @_;
  return $matcher unless $deny;
  sub { $matcher->(@_) ? 'DENY' : undef }
}

sub split_acl {
  my $acl = shift;
  my @parts;
  while ($acl =~ /(DENY:\(.*?\)|DENY:\S+|\S+)/gi) {
    push @parts, $1;
  }
  @parts
}

sub acl_split_channels_nicks {
  my $acl = shift;
  my $channels = [];
  my $nicks = [];
  for my $word (split ' ', $acl) {
    if ($word =~ /^#/) {
      push @$channels, $word;
    } else {
      push @$nicks, $word;
    }
  }
  undef $channels unless @$channels;
  undef $nicks unless @$nicks;
  ($channels, $nicks)
}

sub compile_acl_entries {
  my ($groups, @entries) = @_;
  my $acl = join(' ', @entries);
  my @aclparts = split_acl($acl);
  my @channel_matchers;
  my @nick_matchers;
  my $default_channel_answer = 'any';
  my $default_nick_answer = 'any';
  for my $part (@aclparts) {
    my $deny = $part =~ s/^DENY://;
    if ($part =~ /^\((.*)\)$/) {
      $part = $1;
    }

    my ($channels, $nicks) = acl_split_channels_nicks($part);
    if ($channels) {
      undef $default_channel_answer unless $deny;
      push @channel_matchers,
        invert_matcher($deny, channel_matcher($groups, join(' ', @$channels)));
    }
    if ($nicks) {
      undef $default_nick_answer unless $deny;
      push @nick_matchers,
        invert_matcher($deny, nick_matcher($groups, join(' ', @$nicks)));
    }
  }
  +{
    channel_default => $default_channel_answer,
    nick_default => $default_nick_answer,
    channel_matchers => \@channel_matchers,
    nick_matchers => \@nick_matchers
   }
}

sub channel_matcher {
  my ($groups, $entry) = @_;
  my @channels = split ' ', lc($entry);
  if (grep($_ eq '#*', @channels)) {
    return sub { 'any' };
  }
  my %chanmap;
  my @changroups;
  for my $chan (@channels) {
    if ($chan =~ /^#@(.*)/) {
      push @changroups, $1;
    } else {
      $chan = ':pm' if $chan eq '#:pm';
      $chanmap{$chan} = 1;
    }
  }
  sub {
    my $chan = lc(shift() || '');
    $chan = ':pm' if $chan eq 'msg';
    if ($chanmap{$chan} ||
          (@changroups && $groups &&
             $groups->nick_in_groups($chan, @changroups))) {
      return 'any';
    }
    undef
  }
}

sub nick_matcher {
  my ($groups, $entry) = @_;
  my @parts = split ' ', lc($entry);
  if (grep($_ eq '+authenticated', @parts)) {
    return sub { 'authenticated' };
  }

  if (grep($_ eq '*', @parts)) {
    return sub { 'any' };
  }

  my %nickmap;
  my @groups;
  for my $part (@parts) {
    if ($part =~ /^@/) {
      $part =~ s/^@//;
      push @groups, $part;
    } else {
      $nickmap{$part} = 1;
    }
  }
  sub {
    my $nick = lc(shift());
    if ($nickmap{$nick} ||
          (@groups && $groups && $groups->nick_in_groups($nick, @groups)))
    {
      return 'authenticated';
    }
    undef
  }
}

sub strip_acl_name {
  my $name = shift;
  $name =~ s/^:acl://;
  $name
}

sub matches_permission {
  my ($self, $perm) = @_;
  $self->{matcher}->($perm)
}

sub log_auth {
  my ($self, $nick, $chan) = @_;
  $nick ||= '';
  $chan ||= '';
  print STDERR "permit:$$self{name} $nick/$chan\n";
}

sub log_deny {
  my ($self, $reason, $nick, $chan) = @_;
  $nick ||= '';
  $chan ||= '';
  print STDERR "DENY:$$self{name} $nick/$chan: $reason\n";
}

sub permit {
  my ($self, $nick, $chan) = @_;
  my $channel_auth = $self->channel_match($chan);
  unless ($channel_auth) {
    $self->log_deny('unauthorized channel', $nick, $chan);
    return undef;
  }
  my $nick_auth = $self->nick_match($nick);
  unless ($nick_auth) {
    $self->log_deny('unauthorized nick', $nick, $chan);
    return undef
  }
  $self->log_auth($nick, $chan);
  $nick_auth
}

sub channel_match {
  my ($self, $chan) = @_;
  for my $matcher (@{$self->{rule}{channel_matchers}}) {
    my $result = $matcher->($chan);
    return undef if $result && $result eq 'DENY';
    return $result if $result;
  }
  $self->{rule}{channel_default}
}

sub nick_match {
  my ($self, $nick) = @_;
  for my $matcher (@{$self->{rule}{nick_matchers}}) {
    my $result = $matcher->($nick);
    return undef if $result && $result eq 'DENY';
    return $result if $result;
  }
  $self->{rule}{nick_default}
}

1
