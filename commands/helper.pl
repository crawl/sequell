#!/usr/bin/perl

our $logfile = '/var/www/crawl/allgames.txt';

our @field_names = qw/v lv name uid race cls xl sk sklev title place br lvl
                      ltyp hp mhp mmhp str int dex start dur turn sc ktyp 
                      killer kaux end tmsg vmsg god piety pen char nrune urune/;

our @roles_abbrev = qw/Fi Wz Pr Th Gl Ne Pa As Be Hu Cj En FE IE Su AE EE Cr DK
                       VM CK Tm He XX Re St Mo Wr Wn/;
our @races_abbrev = qw/XX Hu El HE GE DE SE HD MD Ha HO Ko Mu Na Gn Og Tr OM Dr
                       Dr Dr Dr Dr Dr Dr Dr Dr Dr Dr Dr Ce DG Sp Mi DS Gh Ke
                       Mf Vp/;

our @roles =
(
  'fighter',
  'wizard',
  'priest',
  'thief',
  'gladiator',
  'necromancer',
  'paladin',
  'assassin',
  'berserker',
  'hunter',
  'conjurer',
  'enchanter',
  'fire elementalist',
  'ice elementalist',
  'summoner',
  'air elementalist',
  'earth elementalist',
  'crusader',
  'death knight',
  'venom mage',
  'chaos knight',
  'transmuter',
  'healer',
  'quitter',
  'reaver',
  'stalker',
  'monk',
  'warper',
  'wanderer',
);

our @races =
(
  'null',
  'human',
  'elf',
  'high elf',
  'grey elf',
  'deep elf',
  'sludge elf',
  'hill dwarf',
  'mountain dwarf',
  'halfling',
  'hill orc',
  'kobold',
  'mummy',
  'naga',
  'gnome',
  'ogre',
  'troll',
  'ogre mage',
  'red draconian',
  'white draconian',
  'green draconian',
  'golden draconian',
  'grey draconian',
  'black draconian',
  'purple draconian',
  'mottled draconian',
  'pale draconian',
  'unk0 draconian',
  'unk1 draconian',
  'base draconian',
  'centaur',
  'demigod',
  'spriggan',
  'minotaur',
  'demonspawn',
  'ghoul',
  'kenku',
  'merfolk',
  'vampire',
);

our @death_method =
(
  'killed by a monster',
  'succumbed to poison',
  'engulfed by something',
  'killed by a beam',
  'stepped on Death\'s door', #deprecated apparently
  'took a swim in molten lava',
  'drowned',
  'forgot to breathe',
  'collapsed under their own weight',
  'slipped on a banana peel',
  'killed by a trap',
  'got out of the dungeon',
  'escaped with the Orb',
  'quit the game',
  'was drained of all life',
  'starved to death',
  'froze to death',
  'burnt to a crisp',
  'killed by wild magic',
  'killed for Xom\'s enjoyment',
  'killed by a statue',
  'rotted away',
  'killed themself with bad targetting',
  'killed by an exploding spore',
  'smote by The Shining One',
  'turned to stone',
  '<deprecated>',
  'died somehow',
  'fell down a flight of stairs',
  'splashed by acid',
  'asphyxiated',
  'melted into a puddle',
  'bled to death',
);

sub ntimes
{
  my $times = shift;

  $times == 1 ? "once"   :
  $times == 2 ? "twice"  :
  $times == 3 ? "thrice" :
                "$times times"
}

sub once
{
  my $times = shift;

  $times == 1 ? "once"   :
  $times == 2 ? "twice"  :
  $times == 3 ? "thrice" :
                $times
}

sub demunge_logline
{
  my $line = shift;
  my %game;

  $line = substr($line, 1, -1); #remove leading and trailing :

  @game{@field_names} = split /:/, $line;

  return \%game;
}

sub demunge_xlogline
{
  my $line = shift;
  return {} if $line eq '';
  my %game;

  chomp $line;
  die "Unable to handle internal newlines." if $line =~ y/\n//;
  $line =~ s/::/\n\n/g;
  
  while ($line =~ /\G(\w+)=([^:]*)(?::(?=[^:])|$)/cg)
  {
    my ($key, $value) = ($1, $2);
    $value =~ s/\n\n/:/g;
    $game{$key} = $value;
  }

  if (!defined(pos($line)) || pos($line) != length($line))
  {
    my $pos = defined(pos($line)) ? "Problem started at position " . pos($line) . "." : "Regex doesn't match.";
    die "Unable to demunge_xlogline($line).\n$pos";
  }

  return \%game;
}

sub munge_game # DOES THIS WORK? XXX I haven't tested it, and its not in a script yet, so who cares? :)
{
  my $game_ref = shift;
  return join ':', map {my ($k, $v) = ($_, $game{$_}); for ($k, $v) {s/:/::/g } "$k=$v"} keys %game;
  #return ':' . join(':', map {$game_ref->{$_}} @field_names) . ':';
}

sub games_for
{
  my $nick = lc(shift);
  my $regex = qr/:name=$nick:/i;
  my @games;

  open my $handle, '<', $logfile or warn "Unable to open $logfile: $!";
  while (<$handle>)
  {
    chomp;
    if ($_ =~ $regex)
    {
      my $game_ref = demunge_xlogline($_);
      push @games, $game_ref if lc($game_ref->{name}) eq $nick;
    }
  }

  return \@games;
}

sub serialize_time
{
  my $seconds = int shift;
  my $long = shift;

  if (not $long)
  {
    my $hours = int($seconds/3600);
    $seconds %= 3600;
    my $minutes = int($seconds/60);
    $seconds %= 60;

    return sprintf "%d:%02d:%02d", $hours, $minutes, $seconds;
  }
  
  my $minutes = int($seconds / 60);
  $seconds %= 60;
  my $hours = int($minutes / 60);
  $minutes %= 60;
  my $days = int($hours / 24);
  $hours %= 24;
  my $weeks = int($days / 7);
  $days %= 7;
  my $years = int($weeks / 52);
  $weeks %= 52;

  my @fields;
  push @fields, "about ${years}y" if $years;
  push @fields, "${weeks}w"       if $weeks;
  push @fields, "${days}d"        if $days;
  push @fields, "${hours}h"       if $hours;
  push @fields, "${minutes}m"     if $minutes;
  push @fields, "${seconds}s"     if $seconds;

  return join ' ', @fields if @fields;
  return '0s';
}

sub help
{
  if ($ARGV[3])
  {
    print join('', @_) . "\n";
    exit;
  }
}
