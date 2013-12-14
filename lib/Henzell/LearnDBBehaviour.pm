package Henzell::LearnDBBehaviour;

use strict;
use warnings;

use Data::Dumper;
use File::Basename;
use File::Spec;

use lib '..';
use lib File::Spec->catfile(dirname(__FILE__), '../src');
use Henzell::IRCMatcher;

sub new {
  my ($cls, %opt) = @_;
  bless \%opt, $cls
}

sub set_behaviours {
  my $self = shift;
  $self->{behaviours} = [ $self->_parse_behaviours(@_) ];
}

sub _parse_behaviours {
  my $self = shift;
  grep($_ && $_->{match}, map($self->_parse_behaviour($_), @_))
}

sub _parse_behaviour {
  my ($self, $beh) = @_;
  my @pieces = split /:::/, $beh;
  unless (@pieces >= 2) {
    warn "Behaviour $beh is malformed\n";
    return undef;
  }

  my ($matcher, $action, $flags) = @pieces;
  +{ match => $self->_parse_matcher($matcher),
     action => $action,
     flags => $flags }
}

sub _parse_matcher {
  my ($self, $matcher) = @_;
  Henzell::IRCMatcher->parse($matcher, { BOT => $self->{irc}->nick() })
}

sub perform_behaviour {
  my ($self, $m) = @_;
  #warn "Testing ", Dumper($m), " against ", Dumper($self->{behaviours}), "\n";
  for my $beh (@{$self->{behaviours}}) {
    my $res = $self->_behaviour_result($m, $beh);
    next unless $res;

    my $flag = $res->{flags};
    my $empty = $res->{empty};
    if (!$empty) {
      $self->{irc}->post_message(%$m, body => $res->{text});
    }
    last if $flag eq 'break';
    return 1 if ($flag eq 'last') || (!$empty && $flag ne 'continue');
  }
  undef
}

sub _random_nick_in {
  my ($self, $channel, @excluded) = @_;
  my %excluded;
  @excluded{map(lc, @excluded)} = 1;
  my @nicks = grep(!$excluded{lc($_)}, $self->{irc}->channel_nicks($channel));
  $nicks[rand @nicks] || 'Plog'
}

sub env {
  my ($self, $m, $match) = @_;

  my $bot = $self->{irc}->nick();
  my $rnick = $self->_random_nick_in($$m{channel}, $bot, $$m{who});
  my %env = (%$m,
             nick => $$m{who},
             user => $$m{who},
             bot => $bot,
             rnick => $rnick,
             %{$match->{env} || { }});
  $env{uc($_)} = $env{$_} for keys %env;
  %env
}

sub _behaviour_result {
  my ($self, $m, $beh) = @_;

  my $match = $beh->{match}->match($m);
  return undef unless $match;

  my %env = $self->env($m, $match);
  my $flags = $beh->{flags} || '';
  if ($flags) {
    $flags = lc($self->{dblookup}->resolve($m, $flags, 'bare', '', %env) || '');
  }
  s/^\s+//s, s/\s+$//s for $flags;
  my $res_text = $self->{dblookup}->resolve($m, $beh->{action}, 'bare',
                                            $match->{args},
                                            %env) || '';
  s/^\s+//s, s/\s+$//s for $res_text;
  my $empty = !defined($res_text) || $res_text !~ /\S/;
  +{ empty => $empty,
     text => $res_text,
     flags => $flags }
}

1
