package Seen;

use Helper;
use File::Spec;

use Henzell::Root;

sub seen_dir {
  Henzell::Root::root('dat/seendb')
}

sub seen_file {
  my $name = shift;
  File::Spec->catfile(seen_dir(), $name)
}

sub seen {
  my $nick = shift;
  my $target = Helper::cleanse_nick($nick);
  my $file = seen_file($target);
  open my $inf, '<', seen_file($target) or return;
  binmode $handle, ':utf8';
  my $line = <$inf>;
  Helper::demunge_xlogline($line)
}

1
