package Henzell::IRCMatcher;

use strict;
use warnings;

use Data::Dumper;

sub capturing_var {
  my ($self, $var) = @_;
  $var =~ /^[a-z][a-z0-9_]*$/
}

sub match_literal {
  my ($self, $g) = @_;
  $g = "\Q$g";
  $g =~ s/\\ +/\\s+?/g;
  qr/$g/i
}

sub translate_group {
  my ($self, $g, $captures, $ctx) = @_;
  if ($g =~ /^\$(\*?\w+)$/) {
    my $var = $1;
    my $greedy = $var =~ /^\*/;
    $var =~ s/^\*//;
    if ($self->capturing_var($var)) {
      push @$captures, $var;
      return $greedy? '(.+)' : '(\S+?)';
    } else {
      my $expanded = $$ctx{lc $var};
      return $self->match_literal($expanded || "\$$var");
    }
  } else {
    return $self->match_literal($g);
  }
}

sub test_words {
  my $word_count = shift;
  my @chars = ('a'..'z', '0'..'9');
  my @words;
  for my $word (1 .. $word_count) {
    push @words, join('', map(@chars[rand @chars], 8 .. 15));
  }
  join(' ', @words)
}

# Generate random word strings. If the pattern matches any of them,
# disallow it.
sub overpermissive_pattern {
  my ($self, $re) = @_;
  return 1 if '' =~ $re;
  # for my $word (map(test_words($_), 1..6)) {
  #   return 1 if $word =~ $re;
  # }
  0
}

sub parse {
  my ($self, $matcher, $ctx) = @_;
  my %conditions;
  my $original = $matcher;
  $matcher =~ s/\{\{(\w+):([^\}]*)\}\}/ $conditions{$1} = $2, '' /ge;
  $matcher =~ s/\s+/ /g;
  $matcher =~ s/^\s+//;
  $matcher =~ s/\s+$//;

  my @captures;
  my $before = $matcher =~ s/^<<<//;
  my $after = $matcher =~ s/>>>$//;
  push @captures, 'before' if $before;

  my @groups = split(/(?<!\\)(\$\*?\w+)/, $matcher);

  my @re = map($self->translate_group($_, \@captures, $ctx), @groups);
  push @captures, 'after' if $after;
  unshift @re, '\s*?';
  unshift @re, $before ? '^(.*?)' : '^';
  push @re, '\s*?';
  push @re, $after ? '(.*?)$' : '$';

  my $re = qr/@{[join('', @re)]}/;
  if ($self->overpermissive_pattern($re)) {
    warn "Pattern $re for $original is overpermissive, rejecting it\n";
    return undef;
  }

  $self->new(original => $original,
             expr => $re,
             conditions => \%conditions,
             captures => \@captures)
}

sub new {
  my ($cls, %set) = @_;
  bless \%set, $cls
}

sub condition_match {
  my ($self, $m) = @_;
  for my $cond (keys %{$self->{conditions}}) {
    my $val = $self->{conditions}->{$cond} || '';
    return unless ($$m{$cond} || '') eq $val;
  }
  1
}

sub canonical_body {
  my $body = shift;
  s/^\s+//, s/\s+$//, s/\s+/ /g for $body;
  $body
}

sub match {
  my ($self, $m) = @_;
  return unless $self->condition_match($m);
  my $body = canonical_body($$m{body});
  return unless $body =~ /\S/;
  my $re = $self->{expr};
  if ($body =~ $re) {
    my (@bindings) = $body =~ $re;
    my %captures;
    @captures{@{$self->{captures}}} = @bindings;
    print "MATCH: $body: ", Dumper($self), "\n";
    {
      env => { %$m, %captures },
      args => $captures{after}
    }
  }
}

1
