# Joins list of channels in :channels: entry, defaulting to config.
package Henzell::IRCChan;

use strict;
use warnings;

use lib '..';

use LearnDB;
use Henzell::Config;

my $learndb_mtime;
my @channels;

sub channels {
  if (!$learndb_mtime || $learndb_mtime < LearnDB::mtime()) {
    $learndb_mtime = LearnDB::mtime();
    @channels = load_channels();
  }
  if (!@channels) {
    return Henzell::Config::array('channels');
  } else {
    return @channels;
  }
}

sub load_channels {
  my $channels = LearnDB::query_entry_with_redirects(':channels:', 1);
  if (!$channels) {
    return ();
  }
  grep(/^#/, split(' ', $channels))
}

1
