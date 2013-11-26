
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
use Henzell::TemplateExpander;
use LearnDB;
use LearnDB::Entry;

sub new {
  my ($cls, %opt) = @_;
  bless \%opt, $cls
}

sub _expander {
  my $self = shift;
  $self->{_expander} ||= Henzell::TemplateExpander->new()
}

sub _executor {
  shift()->{executor}
}

sub _resolve_redirect {
  my ($self, $redirect) = @_;
  LearnDB::Entry->wrap(
    LearnDB::query_entry($redirect, undef, undef) or "see {$redirect}")
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
  }

  # Make sure we still have something that looks like a LearnDB entry:
  $entry = LearnDB::Entry->wrap($entry);
  my $tpl = $bare ? $entry->formatted_value() : $entry->template();
  $self->_expander()->expand($tpl, $args, %env)
}

1
