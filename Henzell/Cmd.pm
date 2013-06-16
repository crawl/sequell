package Henzell::Cmd;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw/load_commands_from_file clear_commands load_all_commands
                    execute_cmd/;

use lib '..';
use Henzell::UserCommandDb;

our %CMD;
our %USER_CMD;

sub load_commands_from_file($) {
  my $file = shift;
  open my $inf, '<', $file or die "Can't read $file: $!\n";
  while (<$inf>) {
    chomp;
    if (/^\s*(\S+)\s+(\S+)(?:\s+(:direct))?\s*$/) {
      $CMD{$1} = { file => $2, direct => $3 };
    }
  }
}

sub load_all_commands() {
  my @command_files = glob('config/commands-*.txt');
  for my $file (@command_files) {
    load_commands_from_file($file);
  }
  %USER_CMD = Henzell::UserCommandDb::user_commands();
}

sub command_exists($) {
  my $cmd = shift;
  $CMD{$cmd} || $USER_CMD{$cmd}
}

sub clear_commands() {
  %CMD = ();
}

sub execute_cmd($$;$) {
  my ($nick, $cmdline, $ignore_stderr) = @_;
  $cmdline =~ s/^[?][?]/!learn query /;
  my ($cmd) = $cmdline =~ /^(\S+)/;
  my ($target) = $cmdline =~ /^\S+ (\S+)/;
  $target = $nick if !$target || $target !~ /^\w+$/;
  my $script = $CMD{$cmd}{file};

  if (!$script && $USER_CMD{$cmd}) {
    $script = 'user_command.rb';
  }

  if (!$script) {
    return (1, "Command not found: $cmd", $cmd);
  }

  $script = 'user_command.rb' unless $CMD{$cmd}{direct};
  my $executable_command =
    "./commands/$script \Q$target\E \Q$nick\E \Q$cmdline\E ''";
  print "Exec: $executable_command\n";
  my $redirect = $ignore_stderr ? '' : '2>&1';
  my $output = qx/$executable_command $redirect/;
  my $exitcode = ($? >> 8);
  ($exitcode, $output, $executable_command)
}

1;
