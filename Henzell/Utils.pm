package Henzell::Utils;
use base 'Exporter';

use strict;
use warnings;

use Fcntl qw/:flock SEEK_SET SEEK_END/;
use POSIX;

our @EXPORT = qw/tailed_handle/;
our @EXPORT_OK = qw/lock_or_die lock daemonify/;

sub service_def {
  my $service_def = shift;
  die "Bad service def: must have name, command\n" unless ref($service_def) eq 'HASH';
  die "Service def without command\n" unless $service_def->{command};
  die "Service def without name\n" unless $service_def->{name};
  $service_def
}

sub spawn_services {
  my $service_defs = shift;
  return unless $service_defs;
  for my $service_def (@$service_defs) {
    my $service = service_def($service_def);
    spawn_service($service->{name}, $service->{directory}, $service->{command});
  }
}

sub spawn_service {
  my ($service_name, $directory, $commandline) = @_;
  $service_name =~ tr/a-zA-Z 0-9//cd;
  $service_name =~ tr/ /_/;
  $service_name = lc $service_name;
  print "Spawning service $service_name in $directory: $commandline\n";
  my $pid = fork;
  return if $pid;

  if ($directory) {
    chdir $directory or die "Couldn't cd $directory: $!\n";
  }
  my $log_file = "$service_name.log";
  open my $logf, '>', $log_file or die "Can't write $log_file: $!\n";
  $logf->autoflush;
  open STDOUT, '>&', $logf or die "Couldn't redirect stdout\n";
  open STDERR, '>&', $logf or die "Couldn't redirect stderr\n";
  STDOUT->autoflush;
  STDERR->autoflush;
  exec($commandline);
  exit 1
}

##
# Returns a file handle pointing just after the last line of the file
# (presumably at EOF).
sub tailed_handle {
  my $file = shift;
  open my $handle, '<', $file or return;

  # Go to the very end and see if we have a newline there:
  seek($handle, -1, SEEK_END) or return $handle;

  my $offset = tell($handle);
  my $tries = 5;
  while ($tries-- > 0) {
    my $line = <$handle>;
    if (!defined($line) || $line =~ /\n$/) {
      # Excellent! We're done here.
      return $handle;
    }
    # Ugh, seek back to original spot, sleep and hope something was writing
    # to the logfile:
    seek($handle, $offset, SEEK_SET) or return;
    select(undef, undef, undef, 0.25);
  }
}

sub lock_filename {
  my $basename = shift;

  ($basename) = $main::0 =~ m{([^/]+)$} unless $basename;
  die "Could not discover program name in ($0) to acquire lock\n"
    unless $basename;
  my $dir = $ENV{HOME} || '.';
  "$dir/.$basename.lock"
}

sub daemonify {
  umask 0;
  defined(my $pid = fork) or die "Unable to fork: $!";
  exit if $pid;
  setsid or die "Unable to start a new session: $!";
  # Done daemonifying.
}

sub lock_or_exit {
  my $exitcode = shift() || 0;
  my $lockf = lock_filename();
  open LOCKFILE, '>', $lockf or die "Couldn't open $lockf: $!\n";
  flock(LOCKFILE, LOCK_EX | LOCK_NB)
    or exit($exitcode);
}

sub lock {
  my %pars = @_;

  my $lockf = lock_filename($pars{lock_name});
  warn "Locking $lockf\n" if $pars{verbose};
  open LOCKFILE, '>', $lockf or die "Couldn't open $lockf: $!\n";
  flock(LOCKFILE, LOCK_EX) or die "Couldn't lock $lockf: $!\n";
  warn "Locked $lockf...\n" if $pars{verbose};
}

1
