# Tell any speaker if they have messages waiting.
package Henzell::TellService;

use strict;
use warnings;

use Carp;

use lib '..';
use Henzell::Tell;

sub new {
  my ($cls, %opt) = @_;
  croak "Must provide irc service\n" unless $opt{irc};
  bless \%opt, $cls
}

sub event_said {
  my ($self, $m) = @_;

  if (my $cnt = Henzell::Tell::message_count($$m{who})) {
    if (Henzell::Tell::message_notify($$m{who})) {
      # just in case their first command is !messages
      return if $$m{body} =~ /^!messages\b/i;
    }

    $self->{irc}->post_message(
      %$m,
      body => sprintf('%s: You have %d message%s. Use !messages to read %s.',
                      $$m{who},
                      $cnt,
                      $cnt == 1 ? '' : 's',
                      $cnt == 1 ? 'it' : 'them'));
  }
}

1
