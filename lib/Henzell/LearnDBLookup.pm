# Extended LearnDB lookup that handles see/do {<command>}, and expands
# Sequell template expressions. This is a layer over the simple LearnDB
# lookup services provided by LearnDB.pm

package Henzell::LearnDBLookup;

use strict;
use warnings;

use File::Basename;
use File::Spec;

use lib '..';
use lib File::Spec->catfile(dirname(__FILE__), '../src');

use parent 'Henzell::Forkable';

use Henzell::TemplateExpander;
use LearnDB;
use LearnDB::Entry;
use LearnDB::MaybeEntry;

sub new {
  my ($cls, %opt) = @_;
  bless \%opt, $cls
}

sub _expander {
  my $self = shift;
  $self->{expander} ||= Henzell::TemplateExpander->new()
}

sub _executor {
  shift()->{executor}
}

# Resolves a redirect, returns an entry.
sub _resolve_redirect {
  my ($self, $redirect) = @_;
  my $res = LearnDB::query_entry($redirect, undef, undef);
  if (!$res || $res->err()) {
    return LearnDB::Entry->wrap("see {$redirect}");
  }
  $res->entry()
}

sub _recognized_command {
  my ($self, $m, $command) = @_;
  $self->_executor()->recognized_command({ %$m,
                                           body => $command,
                                           verbatim => $command,
                                           proxied => 1})
}

sub _exec_command {
  my ($self, $m, $command) = @_;
  $self->_executor()->execute_command({ %$m,
                                        body => $command,
                                        verbatim => $command,
                                        proxied => 1 })
}

sub resolve {
  my ($self, $m, $entry, $bare, $args, %env) = @_;
  $entry = $self->resolve_entry($m, $entry);
  return $entry if $entry->prop('literal');
  $entry = $self->expand_entry($entry, $m, %env);
  $self->format_entry($entry, $bare)
}

=item $lookup->resolve_entry($m, $entry, $bare, $args, %env)
Resolves redirects and expands see and do command blocks.
=cut
sub resolve_entry {
  my ($self, $m, $entry) = @_;

  return undef unless defined $entry;

  # Normalize
  $entry = LearnDB::Entry->wrap($entry);
  if ($entry->value() =~ /^\s*see\s+\{(.*)\}\s*$/i) {
    $entry = $self->_resolve_redirect($1);
  }
  if ($entry->value() =~ /^\s*(?:see|do)\s+\{(.*)\}\s*$/i) {
    my $command = $1;
    if ($self->_recognized_command($m, $command)) {
      $entry = $self->_exec_command($m, $command);
    }
    # Don't post-expand the output of commands.
    return LearnDB::Entry->wrap($entry)->with_prop(literal => 1);
  }

  LearnDB::Entry->wrap($entry)
}

sub format_entry {
  my ($self, $entry, $bare) = @_;
  $bare ? $entry->formatted_value() : $entry->template()
}

sub expand_entry {
  my ($self, $entry, $m, %env) = @_;
  $entry = LearnDB::Entry->wrap($entry);

  my $res = eval {
    $self->_expander()->expand($entry->value(), '',
                               irc_msg => $m,
                               env => \%env)
  };
  $res = $@ if $@;

  $entry->with_new_value($res)
}

1
