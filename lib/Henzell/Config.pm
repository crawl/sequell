package Henzell::Config;

use strict;
use warnings;

use base 'Exporter';

use lib '..';
use Henzell::ServerConfig;
use YAML::Any;
use Cwd;
use Henzell::UserCommandDb;

our @EXPORT_OK = qw/read get %CONFIG %CMD %USER_CMD %CMDPATH %PUBLIC_CMD
                    @LOGS @MILESTONES/;

use File::Basename;
use File::Spec;
my $DEFAULTS_FILE = File::Spec->catfile(dirname(__FILE__), '../..',
                                        'rc/henzell.defaults');

my %DEFAULT_CONFIG = %{YAML::Any::LoadFile($DEFAULTS_FILE)};
our %CONFIG = %DEFAULT_CONFIG;
our %CMD;
our %USER_CMD;
our %CMDPATH;
our %PUBLIC_CMD;
our @LOGS;
our @MILESTONES;
our $CONFIG_FILE = 'rc/henzell.rc';

my $command_dir = 'commands';
my $user_command_loaded_at;

my %ABBRMAP;

sub get() {
  \%CONFIG
}

sub feat_enabled($) {
  $CONFIG{shift()}
}

sub sigils {
  $CONFIG{sigils}
}

sub command_exists {
  my $command = shift;
  $CMD{$command} || $USER_CMD{$command}
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

sub load_user_commands {
  return unless -f Henzell::UserCommandDb::db_file();
  if ($user_command_loaded_at &&
      $user_command_loaded_at < -M(Henzell::UserCommandDb::db_file()))
  {
    return;
  }
  %USER_CMD = Henzell::UserCommandDb::user_commands();
  $user_command_loaded_at = -M Henzell::UserCommandDb::db_file();
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
    my ($command, $file, $direct) =
      $line =~ /^(\S+)\s+(\S+)(?:\s+(:direct))?\s*$/;
    #print "Loading $command from $file...\n";

    if ($procmaker) {
      $CMD{$command} = $direct ? $procmaker->($command_dir, $file) :
        $procmaker->($command_dir, 'user_command.rb');
    }
    $CMDPATH{$command} = "$command_dir/$file";

    #print "Loaded $command.\n";
    ++$loaded;
  }
  if ($procmaker) {
    $CMD{custom} = $procmaker->($command_dir, 'user_command.rb');
    $CMDPATH{custom} = "$command_dir/user_command.rb";
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
  load_user_commands();

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
