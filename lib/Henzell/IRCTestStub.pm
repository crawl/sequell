package Henzell::IRCTestStub;

use lib '..';
use parent 'Henzell::IRCStub';

sub write {
  my $self = shift;
  push @{$self->{output}}, join('', @_);
}

sub output {
  my $self = shift;
  my $output = join("", @{$self->{output}});
  delete $self->{output};
  $output
}

1
