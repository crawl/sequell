package Henzell::Config;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw/read get %CONFIG %CMD %PUBLIC_CMD @LOGS @MILESTONES/;

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

                      # Make announcements?
                      announce => 0,

                      commands_file => 'commands/commands-henzell.txt',
                      public_commands_file => 'commands/public-commands.txt',

                      # Map hostname abbreviations to full hostnames.
                      'abbr.cao' => 'crawl.akrasiac.org',
                      'abbr.cdo' => 'crawl.develz.org',
                      'abbr.rhf' => 'rl.heh.fi'
                      );

our %CONFIG = %DEFAULT_CONFIG;
our %CMD;
our %PUBLIC_CMD;
our @LOGS;
our @MILESTONES;
our $CONFIG_FILE = 'henzell.rc';

my %ABBRMAP;

sub get() {
  \%CONFIG
}

sub abbrev_load() {
  for my $key (keys %CONFIG) {
    if ($key =~ /^abbr\.(\w+)$/) {
      $ABBRMAP{$1} = $CONFIG{$key};
    }
  }
}

sub abbrev_expand($) {
  my $abbr = shift;
  # Expand if possible, else leave unchanged:
  $ABBRMAP{$abbr} || "\$$abbr"
}

sub abbrev_expand_all($) {
  my $text = shift;
  return $text unless defined $text;
  s/\$(\w+)/abbrev_expand($1)/ge for $text;
  $text
}

sub parse_header_field($$) {
  my ($hash, $piece) = @_;
  my $host = $CONFIG{host} || '';
  if ($piece =~ /^local:(\w+)$/) {
    if ($1 eq $host) {
      $$hash{local} = 1;
      $$hash{src} = $1;
    }
  } elsif ($piece =~ /^remote:(\w+)(?::(.*))?$/) {
    if ($host ne $1) {
      $$hash{remote} = 1;
      $$hash{src} = $1;
      $$hash{url} = abbrev_expand_all($2);
    }
  } elsif ($piece eq 'alpha') {
    $$hash{alpha} = 1;
  } else {
    die "Unknown header field: $piece\n";
  }
}

sub log_header_hash($) {
  my $header = shift;
  s/^\[//, s/\]$// for $header;

  my %hash;
  for my $piece (split(/;/, $header)) {
    s/^\s+//, s/\s+$// for $piece;
    parse_header_field(\%hash, $piece);
  }

  # Has to be either local or remote:
  return undef unless $hash{local} || $hash{remote};

  \%hash
}

sub log_path($$) {
  my ($header, $path) = @_;

  my $log = log_header_hash($header);
  return undef unless $log;
  $$log{path} = $path;
  $log
}

sub load_log_paths($$$) {
  my ($paths, $file, $name) = @_;

  print "Reading paths from $file\n";
  @$paths = ();

  open my $inf, '<', $file or return;

  my $header;

  while (<$inf>) {
    chomp;
    next unless /\S/ && !/^\s*#/;

    s/^\s+//; s/\s+$//;

    if (/^\[.*\]$/) {
      $header = $_;
      next;
    }

    if ($header) {
      my $path = $_;
      my $logpath = log_path($header, $path);
      push @$paths, $logpath if $logpath;
    }
  }
  close $inf;
}

sub load_file_paths() {
  abbrev_load();
  load_log_paths(\@LOGS, $CONFIG{logs}, "logfiles");
  load_log_paths(\@MILESTONES, $CONFIG{milestones}, "milestones");
}

sub load_public_commands($) {
  %PUBLIC_CMD = ();
  open my $inf, '<', $public_commands_file or return;
  while (<$inf>) {
    chomp;
    s/^\s+//; s/\s+$//;
    next if /^#/;
    next unless /\S/;

    if (/^!?(\w+)/) {
      $PUBLIC_CMD{lc($1)} = 1;
    }
  }
  close $inf;
}

sub load_commands($) {
  my $commands_file = shift;

  %CMD = ();

  my $loaded = 0;
  my $skipped = 0;

  my @command_lines = do { local @ARGV = $commands_file; <>};

  foreach my $line (@command_lines)
  {
    my ($command, $file) = $line =~ /^(\S+)\s+(.+)$/;
    print "Loading $command from $file...\n";

    $commands{$command} = sub {
      my ($args, @args) = @_;
      handle_output(run_command($command_dir, $file, $args, @args));
    };

    print "Loaded $command.\n";
    ++$loaded;
  }
}

sub read() {
  %CONFIG = %DEFAULT_CONFIG;

  open my $inf, '<', $CONFIG_FILE;
  if ($inf) {
    while (<$inf>) {
      s/^\s+//; s/\s+$//;
      next unless /\S/;
      if (/^([\w.]+)\s*=\s*(.*)/) {
        $CONFIG{$1} = $2;
      }
    }
    close $inf;
  }

  # So that users don't have to check for undef warnings.
  $CONFIG{host} ||= '';

  load_file_paths();
  load_public_commands($CONFIG{public_commands_file});
  load_commands($CONFIG{commands_file});

  \%CONFIG
}

1
