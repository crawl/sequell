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
  "(?i)$g"
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

sub parse_matcher {
  my ($self, $ctx, $matcher) = @_;
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

  use re::engine::RE2;
  my $re = qr/@{[join('', @re)]}/;
  +{ re => $re, captures => \@captures }
}

sub parse {
  my ($self, $matcher, $ctx) = @_;
  my %conditions;
  my $original = $matcher;
  $matcher =~ s/\{\{(\w+):([^\}]*)\}\}/ $conditions{$1} = $2, '' /ge;
  $matcher =~ s/\s+/ /g;
  $matcher =~ s/^\s+//;
  $matcher =~ s/\s+$//;

  my $m = $self->parse_matcher($ctx, $matcher);
  unless ($matcher) {
    warn "Could not compile pattern for $original\n";
    return undef;
  }

  $self->new(original => $original,
             expr => $m->{re},
             conditions => \%conditions,
             captures => $m->{captures})
}

sub new {
  my ($cls, %set) = @_;
  bless \%set, $cls
}

sub condition_match {
  my ($self, $m) = @_;
  for my $cond (keys %{$self->{conditions}}) {
    my $val = $self->{conditions}->{$cond} || '';
    return unless lc($$m{$cond} || '') eq lc($val);
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
    my %named_captures = %+;
    my %captures;
    @captures{@{$self->{captures}}} = @bindings;
    {
      env => { %$m, %captures, %named_captures },
      args => $captures{after}
    }
  }
}

1
