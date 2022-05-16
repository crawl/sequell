package Henzell::RelayCommandLine;

use lib '..';

=item parse

parses a Sequell !RELAY command of the form:

    !RELAY -nick actinguser -readonly -n 30 -prefix xyzzy !lg

returning a dictionary of relay properties as:

- readonly: 1 if the relaying bot requested a read-only command relay.
            Read-only command relays don't allow modifications to the
            LearnDB or other stateful actions.
- relay[X]: the relay property named X
- outprefix: the prefix to attach to Sequell command output
- nick: the end-user the relaying bot is sending a command to Sequell on behalf of
- n: the number of lines of output the relaying bot is requesting.

=cut

sub parse($) {
  my $relay_command = shift;

  $relay_command =~ s/!RELAY +//;

  my %change;
  my ($params, $cmd) = $relay_command =~ /^((?:(?:-readonly|-r|-\w+ +\S+) +)*)(?:-- +)?(.*)/;
  if ($params =~ /\S/) {
    while ($params =~ /(?:(-readonly|-r)|-(\w+) +(\S+)) +/g) {
      my ($readonly, $key, $val) = ($1, $2, $3);

      if ($readonly) {
        $change{readonly} = 1;
        next;
      }

      $change{"relay$key"} = $val;

      if ($key eq 'prefix' && $val =~ /\S/) {
        $change{outprefix} = $val;
      }
      if ($key eq 'nick' && $val) {
        $change{nick} = $val;
      }
      if ($key eq 'n' && $val > 0) {
        $change{nlines} = $val;
      }
    }
  }
  $change{body} = $cmd;
  $change{verbatim} = $cmd;

  %change
}

1
