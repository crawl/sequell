package Henzell::LearnDBBehaviour;

use strict;
use warnings;

use Data::Dumper;
use File::Basename;
use File::Spec;

use lib '..';
use lib File::Spec->catfile(dirname(__FILE__), '../src');
use Henzell::TemplateExpander;
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
  unless ($beh =~ /^(.*):::(.*)$/) {
    warn "Behaviour $beh is malformed\n";
    return undef;
  }

  my ($matcher, $action) = ($1, $2);
  +{ match => $self->_parse_matcher($matcher),
     action => $action }
}

sub _parse_matcher {
  my ($self, $matcher) = @_;
  Henzell::IRCMatcher->parse($matcher, { BOT => $self->{irc}->nick() })
}

sub behaviour {
  my ($self, $m) = @_;
  #warn "Testing ", Dumper($m), " against ", Dumper($self->{behaviours}), "\n";
  for my $beh (@{$self->{behaviours}}) {
    my $res = $self->behaviour_result($m, $beh);
    return $res if $res;
  }
  undef
}

sub _expander {
  my $self = shift;
  $self->{_expander} ||= Henzell::TemplateExpander->new()
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

sub behaviour_result {
  my ($self, $m, $beh) = @_;

  my $match = $beh->{match}->match($m);
  return undef unless $match;
  $self->{dblookup}->resolve($m, $beh->{action}, 'bare',
                             $match->{args},
                             $self->env($m, $match))
}

1
