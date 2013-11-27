package Henzell::SeenService;

use strict;
use warnings;

use File::Path;

my $SEEN_DIR       = 'dat/seendb';

sub new {
  my ($cls, %opt) = @_;
  my $self = bless { irc => $opt{irc}, root => $SEEN_DIR, %opt }, $cls;
  $self->init();
  $self
}

sub init {
  my $self = shift;
  File::Path::make_path($self->{root});
}

sub seen_update {
  my ($self, $e, $doing) = @_;

  return if $$e{private} || $$e{self} || $$e{sibling};
  my $nick = $$e{who};

  $nick =~ y/'//d;

  my %seen =
  (
    nick => $nick,
    doing => $doing,
    time => time,
  );

  my $seen_dir = $self->{root};
  my $seen_file = "$seen_dir/\L\Q$nick";
  open my $handle, '>', $seen_file or do
  {
    warn "Unable to open $seen_file for writing: $!";
    return;
  };
  binmode $handle, ':utf8';
  print $handle join(':',
                     map {$seen{$_} =~ s/:/::/g; "$_=$seen{$_}"}
                     keys %seen),
                  "\n";
}

sub event_emoted {
  my ($self, $e) = @_;
  $self->seen_update($e, "acting out $$e{who} $$e{body} on $$e{channel}");
}

sub event_chanjoin {
  my ($self, $j) = @_;
  $self->seen_update($j, "joining the channel");
}

sub event_userquit {
  my ($self, $q) = @_;
  my $msg = $$q{body};
  my $verb = $$q{verb} || 'quitting';
  $self->seen_update($q,
                     $msg? "$verb, saying '$msg'"
                       : "$verb");
}

sub event_chanpart {
  my ($self, $m) = @_;
  $$m{verb} = "parting $$m{channel}";
  $self->event_userquit($m);
}

sub event_said {
  my ($self, $m) = @_;
  return if $$m{sibling} || $$m{private};
  $self->seen_update($m, "saying '$$m{verbatim}' on $$m{channel}");
}

1
