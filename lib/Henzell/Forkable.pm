package Henzell::Forkable;

use POE;
use Henzell::Utils;

my $GLOBAL_DISPATCH_ID = 0;

sub async {
  my ($self, $group, $action, $handler) = @_;
  $self->forker()->($group, $action, $handler)
}

sub forker {
  my $self = shift;
  $self->{forker} ||= $self->_build_forker()
}

sub _build_forker {
  my $self = shift;
  my $irc = $self->can('irc') && $self->irc();
  if ($irc && $irc->can('forkit')) {
    return $self->_build_real_forker($irc)
  } else {
    return $self->_nofork()
  }
}

sub _build_real_forker {
  my ($self, $irc) = @_;
  sub {
    my ($fork_group, $action, $handler) = @_;
    ++$GLOBAL_DISPATCH_ID;
    my $unique_handler = "fork_group_${fork_group}_${GLOBAL_DISPATCH_ID}";
    $irc->forkit(run => sub {
                   print STDERR "Running action in $fork_group\n";
                   Henzell::Utils::lock(lock_name => "${fork_group}.lock",
                                        verbose => 1);
                   print $action->(), "\n";
                 },
                 who => 'nobody',
                 handler => $unique_handler,
                 callback => sub {
                   my ($kernel, $output) = @_[KERNEL, ARG0];
                   # Remove handler from kernel:
                   $kernel->state($unique_handler);
                   $handler->($output);
                 });
  }
}

sub _nofork {
  my $self = shift;
  sub {
    my ($fork_group, $action, $handler) = @_;
    $handler->($action->())
  }
}

1
