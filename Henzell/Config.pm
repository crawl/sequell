package Henzell::Config;

use strict;
use warnings;

use base 'Exporter';

use Henzell::ServerConfig;
use YAML::Any;
use Cwd;

our @EXPORT_OK = qw/read get %CONFIG %CMD %CMDPATH %PUBLIC_CMD
                    @LOGS @MILESTONES/;

my %DEFAULT_CONFIG = (use_pm => 0,

                      irc_server => 'chat.freenode.net',
                      irc_port   => 6667,
                      lock_name  => 'henzell',

                      # Does the bot respond to SQL queries (default: NO)
                      sql_queries => 0,
                      # Does the bot store logfiles and milestones in
                      # a SQL db (default: NO)
                      sql_store => 0,

                      # IRC nick
                      bot_nick => 'Henzell',

                      # Make announcements?
                      announce => 0,

                      # Update seen-db
                      seen_update => 1,

                      channels => qq/##crawl ##crawl-dev/,
                      announce_channel => '##crawl',
                      dev_channel => '##crawl-dev',

                      commands_file => 'commands/commands-henzell.txt',
                      public_commands_file => 'commands/public-commands.txt'
                      );

our %CONFIG = %DEFAULT_CONFIG;
our %CMD;
our %CMDPATH;
our %PUBLIC_CMD;
our @LOGS;
our @MILESTONES;
our $CONFIG_FILE = 'rc/henzell.rc';

my $command_dir = 'commands';

my %ABBRMAP;

sub get() {
  \%CONFIG
}

sub load_file_paths() {
  @LOGS = Henzell::ServerConfig::server_logfiles();
  @MILESTONES = Henzell::ServerConfig::server_milestones();
}

sub load_public_commands($) {
  my $public_commands_file = shift;
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

sub load_commands($$) {
  my ($commands_file, $procmaker) = @_;

  %CMD = ();
  %CMDPATH = ();

  my $loaded = 0;
  my $skipped = 0;

  my @command_lines = do { local @ARGV = $commands_file; <>};

  foreach my $line (@command_lines)
  {
    my ($command, $file) = $line =~ /^(\S+)\s+(.+)$/;
    #print "Loading $command from $file...\n";

    $CMD{$command} = $procmaker->($command_dir, $file) if $procmaker;
    $CMDPATH{$command} = "$command_dir/$file";

    #print "Loaded $command.\n";
    ++$loaded;
  }
}

sub setup_env() {
  $ENV{HENZELL_ROOT} = getcwd();
  if ($CONFIG{host}) {
    $ENV{HENZELL_HOST} = $CONFIG{host};
  } else {
    delete $ENV{HENZELL_HOST};
  }

  # If sql queries are enabled, set appropriate environment var.
  if (!$CONFIG{sql_queries}) {
    delete $ENV{HENZELL_SQL_QUERIES};
  }
  else {
    $ENV{HENZELL_SQL_QUERIES} = 'Y';
  }
}

sub read {
  my ($config, $procmaker) = @_;

  %CONFIG = %DEFAULT_CONFIG;

  my $inf;

  my $config_file = $config || $CONFIG_FILE;
  %CONFIG = (%DEFAULT_CONFIG, %{YAML::Any::LoadFile($config_file)});
  # So that users don't have to check for undef warnings.
  $CONFIG{host} ||= '';

  setup_env();

  load_file_paths();
  load_public_commands($CONFIG{public_commands_file});
  load_commands($CONFIG{commands_file}, $procmaker);

  "Loaded " . scalar(keys(%CMD)) . " commands"
}

sub array($) {
  my $key = shift;
  my $value = $CONFIG{$key} || '';
  my @subvalues = split(/ /, $value);
  s/^\s+//, s/\s+$// for @subvalues;
  grep(/\S/, @subvalues)
}

1
