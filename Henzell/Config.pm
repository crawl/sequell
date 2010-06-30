package Henzell::Config;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw/read get %CONFIG/;

my %DEFAULT_CONFIG = (use_pm => 0,

                      milestones => 'def.stones',
                      logs => 'def.logs',

                      # Does the bot respond to SQL queries (default: NO)
                      sql_queries => 0,
                      # Does the bot store logfiles and milestones in
                      # a SQL db (default: NO)
                      sql_store => 0,

                      # IRC nick
                      bot_nick => 'Henzell',

                      this_host => 'cao'

                      # Map hostname abbreviations to full hostnames.
                      'host.cao' => 'crawl.akrasiac.org',
                      'host.cdo' => 'crawl.develz.org',
                      'host.rhf' => 'rl.heh.fi'
                      );

our %CONFIG = %DEFAULT_CONFIG;
our $CONFIG_FILE = 'henzell.rc';

sub get() {
  \%CONFIG
}

sub read() {
  %CONFIG = %DEFAULT_CONFIG;

  open my $inf, '<', $CONFIG_FILE or return;
  while (<$inf>) {
    s/^\s+//; s/\s+$//;
    next unless /\S/;
    if (/^(\w+)\s*=\s*(.*)/) {
      $CONFIG{$1} = $2;
    }
  }
  close $inf;

  \%CONFIG
}

1
