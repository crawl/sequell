#!/usr/bin/perl
use warnings;
use strict;

package Helper;

use base 'Exporter';

use YAML::Any qw/LoadFile/;
use Data::Dumper;
use Henzell::IRC;

my $CONFIG_FILE = 'config/crawl-data.yml';

our $CFG = LoadFile($CONFIG_FILE);

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
                    nick_alias unwon_combos cleanse_nick/;
our %EXPORT_TAGS = (
    logfile => [qw/demunge_logline demunge_xlogline munge_game games_for/],
    skills  => [grep /skill/, @EXPORT_OK],
    races   => ['is_valid_drac_color', grep /race/,  @EXPORT_OK],
    roles   => [grep /role/,  @EXPORT_OK],
    gods    => [grep /god/,   @EXPORT_OK],
);

my $NICKMAP_FILE = 'dat/nicks.map';
my %NICK_ALIASES;
my $nick_aliases_loaded;

# useful variables {{{
#our $source_dir = '/home/doy/coding/src/stone_soup-release/crawl-ref';
our $source_dir = 'current';
# }}}

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
    return undef;
  }

  if ($game{extra_values}) {
    for my $extra_value (split /;;;;/, $game{extra_values}) {
      my ($key, $value) = $extra_value =~ /^(.*?)@=@(.*)/;
      $game{$key} = $value unless $game{$key};
    }
  }

  return \%game;
} # }}}
# }}}

# race/role/skill munging {{{
# skills {{{
# skill list {{{
our @skills = map(lc, @{$CFG->{skills}});

# skill names used by the code {{{
my %code_skills = map {
    my $s = $_;
    $s =~ s/[ &]+/_/g;
    ($_, "SK_" . uc $s)
} @skills;

my %short_skills = map { ($_, ucfirst((split(' ', $_))[0])) } @skills;
%short_skills = (%short_skills, %{$CFG->{'skill-abbreviations'}});

# skill normalization {{{
my %normalize_skill = ((map { ($_, $_) } @skills),
                       (map { lc } (reverse %code_skills)),
                       (map { lc } (reverse %short_skills)),
                       %{$CFG->{'skill-expansions'}});

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
my @drac_colors = @{$CFG->{'species-flavours'}{draconian}};
# }}}
sub is_valid_drac_color { # {{{
    my $color = shift;
    return (grep { $_ eq $color } @drac_colors) > 0;
} # }}}
# race list {{{

sub species_flavours($) {
  my $species = shift;
  my $species_flavours = $CFG->{'species-flavours'};
  if ($$species_flavours{lc $species}) {
    my @flavours = @{$$species_flavours{lc $species}};
    return map("$_ $species", @flavours)
  } else {
    return $species;
  }
}

sub find_species_list() {
  my @species = values %{$CFG->{species}};
  map(species_flavours($_), grep($_ !~ /\*$/, map(lc, @species)))
}

our @races = find_species_list();

# }}}
# genuses {{{

sub resolve_species_list($) {
  my $species = shift;
  if (ref $species) {
    return [ map(species_flavours($_), @$species) ];
  } else {
    return [ species_flavours($species) ];
  }
}

sub build_genus_species_map() {
  my %genus_map;
  my %genus_species = %{$CFG->{'genus-species'}};
  for my $genus (keys %genus_species) {
    $genus_map{"GENPC_\U$genus"} = resolve_species_list($genus_species{$genus});
  }
  %genus_map
}

my %genus_map = build_genus_species_map();

# }}}
# race names used by the code {{{
my %code_races = map {
    my $r = $_;
    $r =~ tr/ -/__/;
    ($_, "SP_" . uc $r)
} @races;

%code_races = (%code_races, %{$CFG->{'species-enum-map-override'}});

# }}}
# short race names {{{

my %race_map = %{$CFG->{species}};
delete @race_map{grep($CFG->{species}{$_} =~ /\*$/, keys %{$CFG->{species}})};

my %short_races;
@short_races{map(lc, values %race_map)} = keys %race_map;

for my $race_name (keys %short_races) {
  my $abbr = $short_races{$race_name};
  my $flavours = $CFG->{'species-flavours'}{$race_name};
  if ($flavours) {
    for my $flavour (@$flavours) {
      my $flavoured_abbr = $flavour ne 'base'? "$abbr\[$flavour]" : $abbr;
      $short_races{"$flavour $race_name"} = $flavoured_abbr;
    }
  }
}

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
    return $short_races{$race || ''};
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
our @roles = grep($_ !~ /\*$/, map(lc, values(%{$CFG->{classes}})));

# }}}
# role names used by the code {{{
my %code_roles = map {
    my $r = $_;
    $r =~ tr/ /_/;
    ($_, "JOB_" . uc $r)
} @roles;
# }}}
# short role names {{{

my %short_roles;
@short_roles{@roles} = grep($CFG->{classes}{$_} !~ /\*$/, keys %{$CFG->{classes}});
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
    $role =~ s/(?:^\s+|\s+$)//g;
    return $normalize_role{$role}
} # }}}
sub short_role { # {{{
    my $role = shift;
    $role = normalize_role $role;
    return $short_roles{$role || ''};
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
    'no god', values %{$$CFG{god}}
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
    (map { (lc $_, $_) } @gods),
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
    $cmdline =~ s/^\S+\s+//;
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
    return short_elapsed_time($seconds);
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

sub short_elapsed_time {
  my $seconds = shift;
  my $hours = int($seconds/3600);
  $seconds %= 3600;
  my $minutes = int($seconds/60);
  $seconds %= 60;

  my $days = int($hours / 24);
  my $years = int($days / 365);
  $days %= 365;
  $hours %= 24;

  my @pieces;
  push @pieces, "${years}y" if $years > 0;
  push @pieces, "${days}d" if $days > 0;
  push @pieces, sprintf("%d:%02d:%02d", $hours, $minutes, $seconds);
  join('+', @pieces)
}

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

sub cleanse_nick {
  Henzell::IRC::cleanse_nick(shift)
}


1;
