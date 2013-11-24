package Henzell::LogReader;

use strict;
use warnings;

use lib '..';
use Henzell::LogParse;
use Henzell::Config;
use POE;

sub new {
  my ($cls, %opt) = @_;
  my $self = bless {
    logfiles => $opt{logfiles} || [],
    milestones => $opt{milestones} || []
  }, $cls;
  $self->_open_handles();

  if ($self->active() && Henzell::Config::feat_enabled('sql_store')) {
    Henzell::LogParse::initialize_sqllog();
  }
  $self
}

sub _open_handles {
  my $self = shift;
  $self->{stonehandles} =
    [ map {
        $_[0]->{milestones} = 1;
        $_[0]
      } Henzell::LogParse::open_handles(@{$self->{milestones}}) ];
  $self->{loghandles} =
    [ Henzell::LogParse::open_handles(@{$self->{logfiles}}) ];

  $self->{active} = scalar($self->_stonehandles()) ||
                    scalar($self->_loghandles());
}

sub active {
  shift()->{active}
}

sub _loghandles {
  @{shift()->{loghandles}}
}

sub _stonehandles {
  @{shift()->{stonehandles}}
}

=item catchup_logs

Loads entries from all logfiles and milestones into the database, ignoring
current filehandle offset and without publishing events for announcements.
=cut

sub catchup_logs {
  my $self = shift;
  $self->_read_logs('catchup', $self->_loghandles(), $self->_stonehandles());
}

sub tail_logs {
  my $self = shift;
  $self->_read_logs(undef, $self->_loghandles(), $self->_stonehandles());
}

sub _read_logs {
  my ($self, $catchup, @logs) = @_;
  for my $log (@logs) {
    if ($catchup) {
      print "Catching up on records from $log->{file}...\n";
    }

    my $event_publisher = $catchup? undef : sub {
      my $record = shift;
      $self->_publish($record);
    };
    Henzell::LogParse::cat_typed_xlogfile(
      $log,
      $catchup? undef : tell($log->{handle}),
      $event_publisher);
  }
}

sub _publish {
  my ($self, $record) = @_;
  POE::Kernel->post('announce_service', 'game_event', $record);
}

1
