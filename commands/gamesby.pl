#!/usr/bin/perl
do 'commands/helper.pl';

help("Summarizes a player's crawl.akrasiac.org career.");

my $nick = shift;
my $games_ref = games_for($nick);

if (@$games_ref == 0)
{
  printf "No games for %s.\n", $nick;
  exit;
}

my $games = 0;
my $first;
my $last;
my $high;
my $turns = 0;
my $time = 0;
my $total = 0;
my $won = 0;

foreach my $game_ref (@$games_ref)
{
  ++$games;
  if ($games == 1)
  {
    $first = $game_ref->{start};
    $high  = $game_ref->{sc};
    $nick  = $game_ref->{name};
  }
  $last = $game_ref->{end};
  $high = $game_ref->{sc} if $game_ref->{sc} > $high;
  $total += $game_ref->{sc};
  $turns += $game_ref->{turn};
  $time  += $game_ref->{dur};
  ++$won if $game_ref->{ktyp} eq 'winning';
}

$first =~ s/^(\d\d\d\d)(\d\d)(\d\d).*/sprintf "%04d%02d%02d", $1, $2+1, $3/e;
$last  =~ s/^(\d\d\d\d)(\d\d)(\d\d).*/sprintf "%04d%02d%02d", $1, $2+1, $3/e;

printf "%s has played %d game%s, between %s and %s, won %s, high score %d, total score %d, total turns %d, total time %s.\n",
	 $nick,
	 $games,
	 $games == 1 ? "" : "s",
	 $first,
	 $last,
	 once($won),
	 $high,
	 $total,
	 $turns,
	 serialize_time($time);

