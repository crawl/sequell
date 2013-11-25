package Henzell::TemplateExpander;

use strict;
use warnings;

use IPC::Open2;
use JSON;

sub new {
  my ($cls, %opt) = @_;
  bless \%opt, $cls
}

sub _root {
  $ENV{HENZELL_ROOT} or die "HENZELL_ROOT is not set\n"
}

sub _echo_service {
  my $self = shift;
  if (!$self->{_iecho}) {
    open2(my $in, my $out, $self->_root() . '/commands/echo-pipe.rb')
      or die "Couldn't spawn echo service\n";
    $self->{_iecho} = $in;
    $self->{_oecho} = $out;
  }
  ($self->{_iecho}, $self->{_oecho})
}

sub expand {
  my ($self, $template, $argline, %variables) = @_;
  my ($in, $out) = $self->_echo_service();
  print $out encode_json({ msg => $template,
                           args => $argline,
                           env => \%variables }), "\n";
  my $res = <$in>;
  my $json = decode_json($res);
  die "Could not parse response: $res\n" unless $json;
  die $json->{err} if $json && $json->{err};
  $json && $json->{res}
}

1
