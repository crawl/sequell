#!/usr/bin/perl
use strict;
use warnings;

our %numeric_fields;

do 'commands/helper.pl';

help("Displays a list of players, possibly satisfying some criteria. See ?? !players.");

my $extended = $ARGV[2] =~ /^![ae]players/i;
my $active   = $ARGV[2] =~ /^!aplayers/i || $ARGV[2] =~ /-[^ ]*a/;
my $screen   = $ARGV[2] =~ /^!aplayers/i || $ARGV[2] =~ /-[^ ]*s/;
my $hp       = $ARGV[2] =~ /-[^ ]*h/;
my $time     = $ARGV[2] =~ /-[^ ]*t/;
my $god      = $ARGV[2] =~ /-[^ ]*g/;
my ($sort)   = $ARGV[2] =~ /-?[^ ]*s=(-?[a-z]+)/i;
my $turns    = 1;

$sort ||= '-xl';

$time = 0; # until greensnark adds realtime to where file

$extended = 1 if $ARGV[2] =~ /-[^ ]*e/;
$extended = 0 if $ARGV[2] =~ /-[^ ]*b/;
$active   = 0 if $ARGV[2] =~ /-[^ ]*i/;
$screen   = 0 if $ARGV[2] =~ /-[^ ]*l/;

$extended = 1 if $hp || $time || $god;

my @inprogpaths = glob('/home/crawl/chroot/dgldir/inprogress-*');
my $rawdatapath = '/var/www/crawl/rawdata';

my @files = map(glob("$_/*"), @inprogpaths);
@files = grep(!m{/\.[^/]*$}, @files);

my @ok_players;
my %game_ref_for;

foreach my $file (@files)
{
  my ($name) = $file =~ m{.*/(.*)};
  (my $nick = $name) =~ s/:.+$//;

  # is he <= 80x24?
  if ($screen)
  {
    my @lines = do {local @ARGV = $file; <>};
    next unless $lines[2] <= 80 && $lines[1] <= 24;
  }

  # is he <10m idle?
  if ($active)
  {
    my @ttyrecs = sort </home/crawl/chroot/dgldir/ttyrec/$nick/*.ttyrec>;
    my $latest = $ttyrecs[-1];
    my $timestamp = (stat $latest)[9];
    next if time - $timestamp >= 60*10;
  }

  # is he in Crawl's equivalent of DYWYPI?
  my $where = do {local @ARGV = "$rawdatapath/$nick/$nick.where"; <>};
  $game_ref_for{$nick} = demunge_xlogline($where);
  next unless $game_ref_for{$nick}{status} eq 'active';

  # bless his little heart!
  push @ok_players, $nick;
}

if (@ok_players == 0)
{
  my @fields;
  push @fields, "<10m idle" if $active;
  push @fields, "playing at <= 80x24" if $screen;

  if (@fields == 0)
  {
    print "I don't see anyone on crawl.akrasiac.org.";
  }
  else
  {
    print "I don't see anyone on who is " . join(' and ', @fields) . ".";
  }
  exit;
}

my $desc = $sort =~ /^-/;
$sort =~ s/^-//;
my $sorter =
  sub {
    my ($a, $b) = @_;
    my $fa = $game_ref_for{$a}{$sort};
    my $fb = $game_ref_for{$b}{$sort};
    my $ord = $numeric_fields{$sort} ? $fa <=> $fb : $fa cmp $fb;
    $desc ? -$ord : $ord
  };

@ok_players = sort { $sorter->($a, $b) } @ok_players;
if ($extended)
{
  @ok_players = map
                    {
                      my $game_ref = $game_ref_for{$_};
                      $game_ref->{place} =~ y/::/:/;

                      my @fields;
                      push @fields, "T:$game_ref->{turn}" if $turns;
                      push @fields, "HP:$game_ref->{hp}/$game_ref->{mhp}" if $hp;
                      push @fields, serialize_time($game_ref->{dur}) if $time;
                      push @fields, $game_ref->{god} if $god;
                      sprintf '%s (L%s %s @ %s, %s)',
                              $_,
                              $game_ref->{xl},
                              $game_ref->{char},
                              $game_ref->{place},
                              join ', ', @fields;
                    }
                      @ok_players;
}

my @fields;
push @fields, "active" if $active;
push @fields, "<=80x24" if $screen;

printf '%d%s player%s: %s%s',
       scalar @ok_players,
       @fields ? ' ' . join(', ', @fields) : '',
       @ok_players == 1 ? '' : 's',
       join(', ', @ok_players),
       "\n";
