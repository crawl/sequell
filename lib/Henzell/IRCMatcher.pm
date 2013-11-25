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

  $self->new(original => $original,
             expr => qr/@{[join('', @re)]}/,
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

sub match {
  my ($self, $m) = @_;
  return unless $self->condition_match($m);
  my $body = $$m{body};
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
