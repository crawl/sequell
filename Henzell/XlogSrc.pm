package Henzell::XlogSrc;

use strict;
use warnings;

use File::Path;
use File::Spec;

our $TARGET_BASE = 'server-xlogs';

use overload fallback => 1, '""' => sub {
  my $xlog = shift;
  $xlog->canonical_name()
};

sub new {
  my ($cls, $name, $logfile, $server) = @_;

  my $tag;
  if (ref($name) eq 'HASH') {
    my $real_name = (keys %$name)[0];
    $tag = $name->{$real_name};
    $name = $real_name;
  }

  bless { name => $name,
          tag => $tag,
          logfile => $logfile,
          server => $server }, $cls
}

sub canonical_name {
  my $self = shift;
  $self->{canonical_name} ||= $self->_make_canonical_name()
}

sub canonical_version {
  my $self = shift;
  $self->{canonical_version} ||= $self->_find_canonical_version()
}

sub source_name {
  my $self = shift;
  my $name = $self->{name};
  $name =~ tr/*//d;
  $name
}

sub tag {
  shift()->{tag}
}

sub alpha {
  my $self = shift;
  $self->canonical_version() eq 'git'
}

sub server {
  my $self = shift;
  $self->{server}
}

sub type {
  my $self = shift;
  $self->{logfile} ? 'logfile' : 'milestones'
}

sub game_type {
  my $self = shift;
  my $name = $self->source_name();
  return 'sprint' if $name =~ /\bspr/i;
  return 'zotdef' if $name =~ /\b(zd|zotdef)\b/i;
  ''
}

sub server_name {
  my $self = shift;
  $self->server()->name()
}

sub http_url {
  my $self = shift;
  $self->{http_url} ||= $self->_find_http_url()
}

sub local_filepath {
  my $self = shift;
  $self->{local_filepath} ||= $self->_find_local_filepath()
}

sub local_source_exists {
  my $self = shift;
  $self->local_filepath() && -f($self->local_filepath())
}

sub target_exists {
  my $self = shift;
  -f($self->target_filepath())
}

# The (overwriteable) place to store downloaded files, or symlink local files.
# The parent directory is guaranteed to exist.
sub target_filepath {
  my $self = shift;
  File::Path::make_path($TARGET_BASE);
  File::Spec->catfile($TARGET_BASE, $self->canonical_name())
}

# Returns the local path to read the file from, preferring the target
# file path and falling back to the local filepath.
sub read_filepath {
  my $self = shift;
  $self->target_exists() ? $self->target_filepath() :
    $self->local_source_exists() ? $self->local_filepath() : undef
}

# Returns true if we can expect this file to be actively updated on the server
sub is_live {
  my $self = shift;
  $self->{name} =~ /\*/
}

sub http_base {
  my $self = shift;
  $self->server()->http_base()
}

sub local_base {
  my $self = shift;
  $self->server()->local_base()
}

sub _find_http_url {
  my $self = shift;
  my $http_base = $self->http_base();
  return undef unless $http_base;
  "$http_base/" . $self->source_name()
}

sub _find_local_filepath {
  my $self = shift;
  my $local_base = $self->local_base();
  return undef unless $local_base;
  File::Spec->catfile($local_base, $self->source_name())
}

sub _make_canonical_name {
  my $self = shift;
  my $canonical_version = $self->canonical_version();
  my $game_type = $self->game_type();
  my $tag = $self->tag();
  my $qualifier = $game_type ? "-$game_type" : "";
  $qualifier .= "-$tag" if $tag;
  ("remote." . $self->server_name() . "-" . $self->type() . "-" .
   $canonical_version . $qualifier)
}

sub _canonicalize_version {
  my ($version, $alpha) = @_;
  return 'git' if $alpha && !$version;
  if ($version) {
    if ($version =~ /^\d{2}/) {
      $version =~ s/^0+//;
      return "0.$version";
    }
    return $version if $version =~ /^\d+(?:[.]\d+)+$/;
    if ($version =~ /^(\d)(\d+)$/) {
      return "$1.$2";
    }
  }
  'any'
}

sub _find_canonical_version {
  my $self = shift;
  my $name = $self->source_name();
  my ($version) = $name =~ /(\d+(?:[.]\d+)+|\d{2,})/;
  my $alpha = $name =~ /\b(?:git|svn|trunk)\b/;
  my $canonical_version;
  eval {
    $canonical_version = _canonicalize_version($version, $alpha);
  };
  die "Bad xlogfile: $name: $@" if $@;
  $canonical_version
}

1
