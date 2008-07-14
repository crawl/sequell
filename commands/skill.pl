#!/usr/bin/perl

use strict;
use warnings;

do 'commands/helper.pl';
help("Search for skill name.");

my @skill_list = qw/SK_FIGHTING SK_SHORT_BLADES SK_LONG_BLADES SK_AXES
	SK_MACES_FLAILS SK_POLEARMS SK_STAVES SK_SLINGS SK_BOWS
	SK_CROSSBOWS SK_DARTS SK_THROWING SK_ARMOUR SK_DODGING
	SK_STEALTH SK_STABBING SK_SHIELDS SK_TRAPS_DOORS SK_UNARMED_COMBAT
	SK_SPELLCASTING SK_CONJURATIONS SK_ENCHANTMENTS SK_SUMMONINGS
	SK_NECROMANCY SK_TRANSLOCATIONS SK_TRANSMIGRATION SK_DIVINATIONS
	SK_FIRE_MAGIC SK_ICE_MAGIC SK_AIR_MAGIC SK_EARTH_MAGIC
	SK_POISON_MAGIC SK_INVOCATIONS SK_EVOCATIONS/;

$_ = $ARGV[2];
s/^!skill\s+(.*)$/$1/;
chomp;

my $search_pattern = $_;
my $output = "";

foreach my $skill (sort @skill_list)
{
	if($skill =~ /.*$search_pattern.*/i)
	{
		$output .= "$skill, ";
	}
}

chop $output; chop $output;
print "Matching skills: $output\n";
