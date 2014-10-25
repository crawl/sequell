package Henzell::ACL::Groups;

use strict;
use warnings;

sub new {
  my $cls = shift;
  bless { groups => { } }, $cls;
}

sub add {
  my ($self, $group_term, @entries) = @_;
  $group_term =~ s/^:group://i;
  $group_term = lc($group_term);
  $self->{groups}{$group_term} = parse_group(@entries);
}

sub nick_in_groups {
  my ($self, $nick, @groups) = @_;
  $_ = lc($_) for $nick, @groups;
  my %visited;
  for my $group (@groups) {
    return 1 if $self->_nick_in_group($nick, $group, \%visited);
  }
  undef
}

sub _nick_in_group {
  my ($self, $nick, $group, $visited_groups) = @_;
  return undef if $visited_groups->{$group};
  my $groupdef = $self->{groups}{$group};
  return undef unless $groupdef;

  $visited_groups->{$group} = 1;
  return 1 if $groupdef->{nicks}{$nick};
  for my $subgroup (@{$groupdef->{subgroups}}) {
    return 1 if $self->_nick_in_group($nick, $subgroup, $visited_groups);
  }
  undef
}

sub parse_group {
  my @entries = @_;
  my @items = split(' ', lc(join(' ', @entries)));
  my @subgroups = map { s/^@//; $_ } grep(/^@/, @items);
  my @nicks = grep(!/^@/, @items);
  my %nickmatch;
  @nickmatch{@nicks} = (1) x @nicks;
  +{
    nicks => \%nickmatch,
    subgroups => \@subgroups
   }
}

1
