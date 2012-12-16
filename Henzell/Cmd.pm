package Henzell::Cmd;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw/load_commands_from_file clear_commands load_all_commands
                    execute_cmd/;

our %CMD;

sub load_commands_from_file($) {
  my $file = shift;
  open my $inf, '<', $file or die "Can't read $file: $!\n";
  while (<$inf>) {
    chomp;
    if (/^\s*(\S+)\s+(\S+)\s*$/) {
      $CMD{$1} = $2;
    }
  }
}

sub load_all_commands() {
  my @command_files = glob('commands/commands-*.txt');
  for my $file (@command_files) {
    load_commands_from_file($file);
  }
}

sub command_exists($) {
  $CMD{(shift)}
}

sub clear_commands() {
  %CMD = ();
}

sub execute_cmd($$) {
  my ($nick, $cmdline) = @_;
  $cmdline =~ s/^[?][?]/!learn query /;
  my ($cmd) = $cmdline =~ /^(\S+)/;
  my ($target) = $cmdline =~ /^\S+ (\S+)/;
  $target = $nick if !$target || $target !~ /^\w+$/;
  my $script = $CMD{$cmd};
  if (!$script) {
    return (1, "Command not found: $cmd", $cmd);
  }

  my $executable_command =
    "./commands/$script \Q$target\E \Q$nick\E \Q$cmdline\E ''";
  my $output = qx/$executable_command 2>&1/;
  my $exitcode = ($? >> 8);
  ($exitcode, $output, $executable_command)
}

1;
