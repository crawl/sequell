# Object for a single server (CAO, etc.) and its logfiles / milestones
package Henzell::SourceServer;

use strict;
use warnings;

use Henzell::XlogSrc;

sub new {
  my ($cls, $yaml_config) = @_;
  my $self = bless { _config => $yaml_config }, $cls;
  $self->initialize();
  $self
}

sub initialize {
  my $self = shift;
  $self->{logfiles} = [map {
    Henzell::XlogSrc->new($_, 1, $self)
  } $self->_expand_files('logfiles')];
  $self->{milestones} = [map {
    Henzell::XlogSrc->new($_, 0, $self)
  } $self->_expand_files('milestones')];
  my %duplicate;
  for my $source (@{$self->{logfiles}}, @{$self->{milestones}}) {
    my $cname = $source->canonical_name();
    if ($duplicate{$cname}) {
      die("xlogfile collision: " . $source->source_name() . " and " .
          $duplicate{$cname}->source_name() . " have same canonical name: " .
          $cname);
    }
    $duplicate{$cname} = $source;
  }
}

sub name {
  my $self = shift;
  $self->{name} ||= $self->{_config}{name}
}

sub local_base {
  my $self = shift;
  $self->{local_base} ||= $self->{_config}{local}
}

sub http_base {
  my $self = shift;
  $self->{http_base} ||= $self->{_config}{base}
}

sub logfiles {
  my $self = shift;
  @{$self->{logfiles}}
}

sub milestones {
  my $self = shift;
  @{$self->{milestones}}
}

sub split_files {
  my $file = shift;
  if (ref($file) eq 'HASH') {
    my $key = (keys %$file)[0];
    my $tag = $file->{$key};
    return map(+{ $_ => $tag }, split_files($key));
  }
  my $asterisked = $file =~ /\*/;
  my $suffix = $asterisked ? '*' : '';
  $file =~ s/\*//g;
  map($_ . $suffix, glob($file))
}

sub _expand_files {
  my ($self, $key) = @_;
  map(split_files($_), @{$self->{_config}{$key}})
}

1
