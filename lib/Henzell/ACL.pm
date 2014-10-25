package Henzell::ACL;

use strict;
use warnings;

use LearnDB;
use Henzell::ACL::Groups;
use Henzell::ACL::Rule;

=item has_permission

Given a permission, a user nick, and a boolean set true if the nick is
authenticated, checks if the user has the given permission.

If the user does not have the permission, returns undefined.

If the user has the permission, returns 'ok'

If the user would have the permission if they're authenticated,
returns 'authenticate'.

=cut

my $ACL_DB;

sub permission_acl {
  my $permission = shift;
  acl_db()->acl($permission)
}

sub has_permission {
  my ($permission, $nick, $channel, $authenticated, $denydefault) = @_;

  my $perm = acl_db()->nick_has_permission($nick, $channel, $permission,
                                           $denydefault);
  return undef unless $perm;
  $authenticated || $perm eq 'any' ? 'ok' : 'authenticate'
}

sub acl_db {
  $ACL_DB ||= Henzell::ACL->new(LearnDB::db());
}

sub new {
  my ($cls, $db) = @_;
  bless { db => $db }, $cls
}

sub nick_has_permission {
  my ($self, $nick, $channel, $permission, $denydefault) = @_;
  my $acl = $self->acl($permission);

  unless ($acl) {
    return $denydefault ? undef : 'any';
  }
  # If there's no ACL defined, the nick is permitted to perform the action.
  $acl->permit($nick, $channel)
}

sub _db {
  shift()->{db}
}

sub _groups {
  shift()->{_groups}
}

sub _acls {
  @{shift()->{_acls}}
}

sub _load_acls {
  my $self = shift;
  my $db = $self->_db();
  my $load_time = $self->{_load_time};
  return if $load_time && $load_time >= $db->mtime();

  $self->{_load_time} = $db->mtime();

  delete $self->{_acls};
  delete $self->{_groups};
  my @acl_terms = sort {
    my $lc = length($b) <=> length($a);
    return $lc if $lc;
    $a cmp $b
  } @{$db->terms_prefixed(':acl:')};
  my @group_terms = @{$db->terms_prefixed(':group:')};
  $self->_load_groups(@group_terms);
  $self->_load_acl_terms(@acl_terms);
}

sub _load_groups {
  my ($self, @group_terms) = @_;
  my $db = $self->_db();
  my @groups;
  my $groups = Henzell::ACL::Groups->new();
  for my $term (@group_terms) {
    my @expansions = $self->_term_definitions($term);
    $groups->add($term, @expansions);
  }
  $self->{_groups} = $groups;
}

sub _term_definitions {
  my ($self, $term) = @_;
  my $db = $self->_db();
  my $count = $db->definition_count($term);
  my @defs;
  for my $i (1..$count) {
    my $maybe_entry = LearnDB::query_entry($term, $i);
    my $entry = $maybe_entry && $maybe_entry->entry();
    if ($entry && !LearnDB::entry_redirect($entry)) {
      my $value = $entry->value();
      push @defs, $value;
    }
  }
  @defs
}

sub _load_acl_terms {
  my ($self, @acl_terms) = @_;
  my $db = $self->_db();

  my $groups = $self->_groups();
  my @acls;
  for my $term (@acl_terms) {
    my @defs = $self->_term_definitions($term);
    push @acls, $self->_create_acl($groups, $term, @defs);
  }
  $self->{_acls} = \@acls;
}

sub _create_acl {
  my ($self, $groups, $term, @defs) = @_;
  Henzell::ACL::Rule->new($groups, $term, @defs)
}

sub acl {
  my ($self, $permission) = @_;
  $self->_load_acls();
  for my $acl ($self->_acls()) {
    return $acl if $acl->matches_permission($permission);
  }
  undef
}

1
