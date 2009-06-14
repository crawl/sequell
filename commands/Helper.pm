#!/usr/bin/perl
use warnings;
use strict;
package Helper;
use base 'Exporter';
our @EXPORT = qw/$source_dir error help strip_cmdline/;
our @EXPORT_OK = qw/$logfile demunge_logline demunge_xlogline munge_game
                    games_for
                    @skills normalize_skill short_skill code_skill
                    display_skill
                    @races genus_to_races is_valid_drac_color normalize_race
                    short_race code_race display_race
                    @roles normalize_role short_role code_role display_role
                    @gods normalize_god short_god code_god display_god
                    ntimes once serialize_time ucfirst_word
                    nick_alias/;
our %EXPORT_TAGS = (
    logfile => [qw/demunge_logline demunge_xlogline munge_game games_for/],
    skills  => [grep /skill/, @EXPORT_OK],
    races   => ['is_valid_drac_color', grep /race/,  @EXPORT_OK],
    roles   => [grep /role/,  @EXPORT_OK],
    gods    => [grep /god/,   @EXPORT_OK],
);

my $NICKMAP_FILE = 'nicks.map';
my %NICK_ALIASES;
my $nick_aliases_loaded;

# useful variables {{{
#our $source_dir = '/home/doy/coding/src/stone_soup-release/crawl-ref';
our $source_dir = 'current';
our $logfile    = '/var/www/crawl/allgames.txt';
# }}}

# logfile parsing {{{
{
my @field_names = qw/v lv name uid race cls xl sk sklev title place br lvl
                     ltyp hp mhp mmhp str int dex start dur turn sc ktyp
                     killer kaux end tmsg vmsg god piety pen char nrune urune/;

my @roles_abbrev = qw/Fi Wz Pr Th Gl Ne Pa As Be Hu Cj En FE IE Su AE EE Cr DK
                      VM CK Tm He XX Re St Mo Wr Wn/;
my @races_abbrev = qw/XX Hu El HE GE DE SE HD MD Ha HO Ko Mu Na Gn Og Tr OM Dr
                      Dr Dr Dr Dr Dr Dr Dr Dr Dr Dr Dr Ce DG Sp Mi DS Gh Ke Mf DD/;

my @roles = (
  'fighter', 'wizard', 'priest', 'thief', 'gladiator', 'necromancer',
  'paladin', 'assassin', 'berserker', 'hunter', 'conjurer', 'enchanter',
  'fire elementalist', 'ice elementalist', 'summoner', 'air elementalist',
  'earth elementalist', 'crusader', 'death knight', 'venom mage',
  'chaos knight', 'transmuter', 'healer', 'quitter', 'reaver', 'stalker',
  'monk', 'warper', 'wanderer',
);

my @races = (
  'null', 'human', 'elf', 'high elf', 'grey elf', 'deep elf', 'sludge elf',
  'hill dwarf', 'mountain dwarf', 'halfling', 'hill orc', 'kobold', 'mummy',
  'naga', 'gnome', 'ogre', 'troll', 'ogre mage', 'red draconian',
  'white draconian', 'green draconian', 'yellow draconian', 'grey draconian',
  'black draconian', 'purple draconian', 'mottled draconian', 'pale draconian',
  'unk0 draconian', 'unk1 draconian', 'base draconian', 'centaur', 'demigod',
  'spriggan', 'minotaur', 'demonspawn', 'ghoul', 'kenku', 'merfolk', 'deep dwarf'
);

my @death_method = (
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

sub demunge_logline # {{{
{
  my $line = shift;
  my %game;

  $line = substr($line, 1, -1); #remove leading and trailing :

  @game{@field_names} = split /:/, $line;

  return \%game;
} # }}}
sub demunge_xlogline # {{{
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
} # }}}
sub munge_game # {{{
# DOES THIS WORK? XXX I haven't tested it, and its not in a script yet, so who
# cares? :)
{
  my $game_ref = shift;
  my %game = %{$game_ref};
  return join ':', map {my ($k, $v) = ($_, $game{$_}); for ($k, $v) {s/:/::/g } "$k=$v"} keys %game;
  #return ':' . join(':', map {$game_ref->{$_}} @field_names) . ':';
} # }}}
sub games_for # {{{
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
} # }}}
}
# }}}

# race/role/skill munging {{{
# skills {{{
# skill list {{{
our @skills = (
    'fighting', 'short blades', 'long blades', 'axes', 'maces & flails',
    'polearms', 'staves', 'slings', 'bows', 'crossbows', 'darts', 'throwing',
    'armour', 'dodging', 'stealth', 'stabbing', 'shields', 'traps & doors',
    'unarmed combat', 'spellcasting', 'conjurations', 'enchantments',
    'summonings', 'necromancy', 'translocations', 'transmutations',
    'divinations', 'fire magic', 'ice magic', 'air magic', 'earth magic',
    'poison magic', 'invocations', 'evocations', 'experience',
); # }}}
# skill names used by the code {{{
my %code_skills = map {
    my $s = $_;
    $s =~ s/[ &]+/_/g;
    ($_, "SK_" . uc $s)
} @skills;
# }}}
# short skills {{{
my %short_skills = map { ($_, ucfirst((split(' ', $_))[0])) } @skills;
$short_skills{'crossbows'}      = 'Xbows';
$short_skills{'throwing'}       = 'Throw';
$short_skills{'dodging'}        = 'Dodge';
$short_skills{'stabbing'}       = 'Stab';
$short_skills{'spellcasting'}   = 'Splcast';
$short_skills{'conjurations'}   = 'Conj';
$short_skills{'enchantments'}   = 'Ench';
$short_skills{'summonings'}     = 'Summ';
$short_skills{'necromancy'}     = 'Nec';
$short_skills{'translocations'} = 'Tloc';
$short_skills{'transmutations'} = 'Tmut';
$short_skills{'divinations'}    = 'Div';
$short_skills{'invocations'}    = 'Inv';
$short_skills{'evocations'}     = 'Evo';
$short_skills{'experience'}     = 'Exp';
# }}}
# skill normalization {{{
my %normalize_skill = (
    (map { ($_, $_) } @skills),
    (map { lc } (reverse %code_skills)),
    (map { lc } (reverse %short_skills)),
    pois     => 'poison magic',
    flails   => 'maces & flails',
    invo     => 'invocations',
    necro    => 'necromancy',
    tmut => 'transmutations',
    doors    => 'traps & doors',
    armor    => 'armour',
    uc       => 'unarmed combat',
); # }}}
sub normalize_skill { # {{{
    my $skill = shift;
    $skill = lc $skill;
    $skill =~ s/(?:^\s*|\s*$)//g;
    my $alt = $skill !~ /s$/ && "${skill}s";
    return $normalize_skill{$skill} || ($alt && normalize_skill($alt));
} # }}}
sub short_skill { # {{{
    my $skill = shift;
    $skill = normalize_skill $skill;
    return $short_skills{$skill};
} # }}}
sub code_skill { # {{{
    my $skill = shift;
    $skill = normalize_skill $skill;
    return $code_skills{$skill};
} # }}}
sub display_skill { # {{{
    my $skill = shift;
    $skill = normalize_skill $skill;
    return ucfirst_word($skill);
} # }}}
# }}}
# races {{{
# draconians {{{
my @drac_colors = qw/red white green yellow grey black purple mottled pale/;
# }}}
sub is_valid_drac_color { # {{{
    my $color = shift;
    return (grep { $_ eq $color } @drac_colors) > 0;
} # }}}
# race list {{{
our @races = (
    'human', 'high elf', 'deep elf', 'sludge elf',
    'mountain dwarf', 'halfling', 'hill orc', 'kobold', 'mummy', 'naga',
    'ogre', 'troll',
    (map { "$_ draconian" } @drac_colors),
    'base draconian', 'centaur', 'demigod', 'spriggan', 'minotaur',
    'demonspawn', 'ghoul', 'kenku', 'merfolk', 'vampire', 'deep dwarf'
);
# }}}
# genuses {{{
my %genus_map = (
    GENPC_DRACONIAN => [map { "$_ draconian" } (@drac_colors, "base")   ],
    GENPC_ELVEN     => [map { "$_ elf"       } qw/high grey deep sludge/],
    GENPC_DWARVEN   => ['mountain dwarf', 'deep dwarf'],
    GENPC_OGRE      => [qw/ogre/],
);
# }}}
# race names used by the code {{{
my %code_races = map {
    my $r = $_;
    $r =~ tr/ -/__/;
    ($_, "SP_" . uc $r)
} @races;
# }}}
# short race names {{{
my %short_races = map {
    my @r = split /[ -]/;
    ($_, @r == 1 ? ucfirst (substr $_, 0, 2) :
                   uc (substr $r[0], 0, 1) . uc (substr $r[1], 0, 1))
} @races;
$short_races{'demigod'}        = 'DG';
$short_races{'demonspawn'}     = 'DS';
$short_races{'merfolk'}        = 'Mf';
$short_races{'vampire'}        = 'Vp';
$short_races{'base draconian'} = 'Dr';
$short_races{"$_ draconian"}   = "Dr[$_]" for @drac_colors;
# }}}
# race normalization {{{
my %normalize_race = (
    (map { ($_, $_) } @races),
    (map { lc } (reverse %code_races)),
    (map { lc } (reverse %short_races)),
    'draconian' => 'base draconian',
);
# }}}
sub genus_to_races { # {{{
    my $genus = shift;
    return @{ $genus_map{$genus} };
} # }}}
sub normalize_race { # {{{
    my $race = shift;
    $race = lc $race;
    $race =~ s/(?:^\s*|\s*$)//g;
    return $normalize_race{$race}
} # }}}
sub short_race { # {{{
    my $race = shift;
    $race = normalize_race $race;
    return $short_races{$race};
} # }}}
sub code_race { # {{{
    my $race = shift;
    $race = normalize_race $race;
    return $code_races{$race};
} # }}}
sub display_race { # {{{
    my $race = shift;
    $race = normalize_race $race;
    return 'Ogre-Mage' if $race eq 'ogre-mage';
    return 'Draconian' if $race eq 'base draconian';
    return ucfirst_word($race);
} # }}}
# }}}
# roles {{{
# role list {{{
our @roles = (
    'fighter', 'wizard', 'priest', 'thief', 'gladiator', 'necromancer',
    'paladin', 'assassin', 'berserker', 'hunter', 'conjurer', 'enchanter',
    'fire elementalist', 'ice elementalist', 'summoner', 'air elementalist',
    'earth elementalist', 'crusader', 'death knight', 'venom mage',
    'chaos knight', 'transmuter', 'healer', 'reaver', 'stalker', 'monk',
    'warper', 'wanderer',
);
# }}}
# role names used by the code {{{
my %code_roles = map {
    my $r = $_;
    $r =~ tr/ /_/;
    ($_, "JOB_" . uc $r)
} @roles;
# }}}
# short role names {{{
my %short_roles = map {
    my @r = split ' ';
    ($_, @r == 1 ? ucfirst (substr $_, 0, 2) :
                   uc (substr $r[0], 0, 1) . uc (substr $r[1], 0, 1))
} @roles;
$short_roles{'wizard'} = 'Wz';
$short_roles{'conjurer'} = 'Cj';
$short_roles{'transmuter'} = 'Tm';
$short_roles{'warper'} = 'Wr';
$short_roles{'wanderer'} = 'Wn';
# }}}
# role normalization {{{
my %normalize_role = (
    (map { ($_, $_) } @roles),
    (map { lc } (reverse %code_roles)),
    (map { lc } (reverse %short_roles)),
);
# }}}
sub normalize_role { # {{{
    my $role = shift;
    $role = lc $role;
    $role =~ s/(?:^\s*|\s*$)//g;
    return $normalize_role{$role}
} # }}}
sub short_role { # {{{
    my $role = shift;
    $role = normalize_role $role;
    return $short_roles{$role};
} # }}}
sub code_role { # {{{
    my $role = shift;
    $role = normalize_role $role;
    return $code_roles{$role};
} # }}}
sub display_role { # {{{
    my $role = shift;
    $role = normalize_role $role;
    return ucfirst_word($role);
} # }}}
# }}}
# gods {{{
# god list {{{
our @gods = (
    'no god', 'zin', 'the shining one', 'kikubaaqudgha', 'yredelemnul', 'xom',
    'vehumet', 'okawaru', 'makhleb', 'sif muna', 'trog', 'nemelex xobeh',
    'elyvilon', 'lugonu', 'beogh',
);
# }}}
# god names used by the code {{{
my %code_gods = map {
    my $g = $_;
    $g =~ tr/ /_/;
    ($_, "GOD_" . uc $g)
} @roles;
$code_gods{'the shining one'} = 'GOD_SHINING_ONE';
# }}}
# short god names {{{
my %short_gods = map {
    my @g = split ' ';
    ($_, ucfirst (substr $g[0], 0, 4))
} @gods;
$short_gods{'no god'} = 'None';
$short_gods{'the shining one'} = 'TSO';
$short_gods{'okawaru'} = 'Oka';
$short_gods{'elyvilon'} = 'Ely';
# }}}
# god normalization {{{
my %normalize_god = (
    (map { ($_, $_) } @gods),
    (map { lc } (reverse %code_gods)),
    (map { lc } (reverse %short_gods)),
    nemelex => 'nemelex xobeh',
);
# }}}
sub normalize_god { # {{{
    my $god = shift;
    $god = lc $god;
    $god =~ s/(?:^\s*|\s*$)//g;
    return $normalize_god{$god}
} # }}}
sub short_god { # {{{
    my $god = shift;
    $god = normalize_god $god;
    return $short_gods{$god};
} # }}}
sub code_god { # {{{
    my $god = shift;
    $god = normalize_god $god;
    return $code_gods{$god};
} # }}}
sub display_god { # {{{
    my $god = shift;
    $god = normalize_god $god;
    return ucfirst_word($god);
} # }}}
# }}}
# }}}

# helper functions {{{
sub error # {{{
{
  print @_, "\n";
  exit;
} # }}}
sub help # {{{
{
  error @_ if $ARGV[3];
} # }}}
sub strip_cmdline # {{{
{
    my $cmdline = shift;
    my %args = @_;
    $cmdline =~ s/^!\w+\s+//;
    chomp $cmdline;
    $cmdline = lc $cmdline unless $args{case_sensitive};
    $cmdline = join(' ', split(' ', $cmdline));
    return $cmdline;
} # }}}
sub ntimes # {{{
{
  my $times = shift;

  $times == 1 ? "once"   :
  $times == 2 ? "twice"  :
  $times == 3 ? "thrice" :
                "$times times"
} # }}}
sub once # {{{
{
  my $times = shift;

  $times == 1 ? "once"   :
  $times == 2 ? "twice"  :
  $times == 3 ? "thrice" :
                $times
} # }}}
sub serialize_time # {{{
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
} # }}}
sub ucfirst_word { # {{{
    join ' ', map { ucfirst } split / /, shift;
} # }}}
# }}}

sub load_nick_aliases {
  return \%NICK_ALIASES if $nick_aliases_loaded;

  if (-f $NICKMAP_FILE) {
    open my $inf, '<', $NICKMAP_FILE or return { };
    while (<$inf>) {
      chomp;
      my @nicks = split;
      $NICK_ALIASES{lc($nicks[0])} =
        join(" ", @nicks[1 .. $#nicks]) if @nicks > 1;
    }
    close $inf;
  }
  $nick_aliases_loaded = 1;
  \%NICK_ALIASES
}

sub nick_alias {
  my $nick = shift;
  my $aliases = load_nick_aliases()->{lc $nick};

  $aliases && $aliases =~ /^(\S+)/ ? $1 : $nick
}

1;
