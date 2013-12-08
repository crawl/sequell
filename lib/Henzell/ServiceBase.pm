package Henzell::ServiceBase;

sub bus {
  shift()->{bus}
}

sub subscribe_event {
  my ($self, $alias, $event, $action) = @_;
  my $bus = $self->bus();
  $bus->subscribe($self, $alias, $event, $action) if $bus;
}

sub publish_event {
  my ($self, $target, $event, @args) = @_;
  my $bus = $self->bus();
  $bus->publish($target, $event, @args) if $bus;
}

1
