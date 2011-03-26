package Henzell::Utils;
use base 'Exporter';

use strict;
use warnings;

use Fcntl qw/:flock SEEK_SET SEEK_END/;
use POSIX;

our @EXPORT = qw/tailed_handle/;
our @EXPORT_OK = qw/lock_or_die lock daemonify/;

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
