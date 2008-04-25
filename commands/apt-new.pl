#!/usr/bin/perl
use strict;
use warnings;

do 'commands/helper.pl';
help("Looks up aptitudes for specified race/skill combination.");

our (%fullDB, %transRaceDB, %skillList, %bestApt, %dracColours, @gameOrder);
sub buildTransDB # {{{
{
	%dracColours = (red=>"SP_RED_DRACONIAN", white=>"SP_WHITE_DRACONIAN",
					green=>"SP_GREEN_DRACONIAN", yellow=>"SP_YELLOW_DRACONIAN",
					grey=>"SP_GREY_DRACONIAN", black=>"SP_BLACK_DRACONIAN",
					purple=>"SP_PURPLE_DRACONIAN", mottled=>"SP_MOTTLED_DRACONIAN",
					pale=>"SP_PALE_DRACONIAN");
	@gameOrder = ("SK_FIGHTING", "SK_SHORT_BLADES", "SK_LONG_BLADES", "SK_AXES",
			"SK_MACES_FLAILS", "SK_POLEARMS", "SK_STAVES", "SK_UNARMED_COMBAT",
			"SK_THROWING", "SK_SLINGS", "SK_BOWS", "SK_CROSSBOWS", "SK_DARTS", 
			"SK_ARMOUR", "SK_DODGING", "SK_STEALTH", "SK_STABBING", "SK_SHIELDS", "SK_TRAPS_DOORS",
			"SK_SPELLCASTING", "SK_CONJURATIONS", "SK_ENCHANTMENTS", "SK_SUMMONINGS",
			"SK_NECROMANCY", "SK_TRANSLOCATIONS", "SK_TRANSMIGRATION", "SK_DIVINATIONS",
			"SK_FIRE_MAGIC", "SK_ICE_MAGIC", "SK_AIR_MAGIC", "SK_EARTH_MAGIC", "SK_POISON_MAGIC",
			"SK_INVOCATIONS", "SK_EVOCATIONS");
	%skillList = ("SK_FIGHTING"=>"Fighting", "SK_SHORT_BLADES"=>"Short",
		"SK_LONG_BLADES"=>"Long", "SK_AXES"=>"Axes", "SK_MACES_FLAILS"=>"Maces",
		"SK_POLEARMS"=>"Polearms", "SK_STAVES"=>"Staves", "SK_SLINGS"=>"Slings",
		"SK_BOWS"=>"Bows", "SK_CROSSBOWS"=>"Crossbows", "SK_DARTS"=>"Darts",
		"SK_THROWING"=>"Throw", "SK_ARMOUR"=>"Armour",
		"SK_DODGING"=>"Dodge", "SK_STEALTH"=>"Stealth", "SK_STABBING"=>"Stab",
		"SK_SHIELDS"=>"Shields", "SK_TRAPS_DOORS"=>"Traps",
		"SK_UNARMED_COMBAT"=>"Unarmed", "SK_SPELLCASTING"=>"Spellcasting",
		"SK_CONJURATIONS"=>"Conj", "SK_ENCHANTMENTS"=>"Ench",
		"SK_SUMMONINGS"=>"Summ", "SK_NECROMANCY"=>"Nec",
		"SK_TRANSLOCATIONS"=>"Tloc", "SK_TRANSMIGRATION"=>"Tmig",
		"SK_DIVINATIONS"=>"Div", "SK_FIRE_MAGIC"=>"Fire", "SK_ICE_MAGIC"=>"Ice",
		"SK_AIR_MAGIC"=>"Air", "SK_EARTH_MAGIC"=>"Earth",
		"SK_POISON_MAGIC"=>"Poison", "SK_INVOCATIONS"=>"Inv",
		"SK_EVOCATIONS"=>"Evo");
	%transRaceDB = (Hu=>"SP_HUMAN",
				HE=>"SP_HIGH_ELF",
				GE=>"SP_GREY_ELF",
				DE=>"SP_DEEP_ELF",
				SE=>"SP_SLUDGE_ELF",
				MD=>"SP_MOUNTAIN_DWARF",
				Ha=>"SP_HALFLING",
				HO=>"SP_HILL_ORC",
				Ko=>"SP_KOBOLD",
				Mu=>"SP_MUMMY",
				Na=>"SP_NAGA",
				Gn=>"SP_GNOME",
				Og=>"SP_OGRE",
				Tr=>"SP_TROLL",
				OM=>"SP_OGRE_MAGE",
				Dr=>"SP_BASE_DRACONIAN",
				Ce=>"SP_CENTAUR",
				DG=>"SP_DEMIGOD",
				Sp=>"SP_SPRIGGAN",
				Mi=>"SP_MINOTAUR",
				DS=>"SP_DEMONSPAWN",
				Gh=>"SP_GHOUL",
				Ke=>"SP_KENKU",
				Mf=>"SP_MERFOLK",
				Vp=>"SP_VAMPIRE");
} # }}}
sub parseSkillsFile # {{{
{
	open my $infile, "<", "db.cc";
	my $currRace;
	while(<$infile>)
	{
		# Determine race
		if(m#\{\s*// ([A-Z\(\)0-9_]+)#)
		{
			$currRace=$1 if(m#\{\s*// ([A-Z\(\)0-9_]+)#);
		}

		# Determine attribute and aptitude
		if(m#^\s*([ 0-9-\+\(\)/\*]+),\s+// ([A-Z0-9_]+)#)
		{
			my $evaled = (eval $1);
			if( defined($currRace) )		# This figures out what the best
			{								# aptitudes are.
				if( defined($bestApt{$2}) )	# Check if the old value is better
				{
					$bestApt{$2}=$evaled if($evaled < $bestApt{$2});
				}
				else						# If there is no old value, just store
				{
					$bestApt{$2}=$evaled;
				}
				$fullDB{$currRace}{$2}=$evaled if( defined($currRace) );
			}
		}
	}
} # }}}

# Prepare DB's
buildTransDB();
parseSkillsFile();
$_ = $ARGV[2];

chomp;
s/^!apt\s+(.*)$/$1/;
my ($race, $skill, $sort, $colour);
my @args = split / /;

# parse arguments
foreach (@args)
{
	if(/r=([A-Za-z]{2})/)	{$race=$1;}		# -race=Sp
	elsif(/s=([A-Z_]*)/)	{$skill=$1;}	# -skill=SK_DODGING
	elsif(/so=([a-z]*)/)	{$sort=$1;}		# -sort=alph
	elsif(/c=([a-z]*)/)		{$colour=$1;}	# -colour=red
}

if( defined($race) )						# atleast $race is defined
{
	if( defined($skill) )						# $race && $skill are defined {{{
	{
		if( defined($colour) )					# $race && $skill && $colour are defined
		{
			# checking for invalid arguments
			unless( defined($transRaceDB{$race}) )	{ print "Not a valid race.\n"; next; }
			unless( defined($skillList{$skill}) )	{ print "Not a valid skill.\n"; next; }
			unless( defined($dracColours{$colour}))	{ print "Non valid colour.\n"; next; }

			# Check for dracs
			if($race eq "Dr")
			{
				my $fullRace = $dracColours{$colour};
				print "Dr[$colour]($skill)=", $fullDB{$fullRace}{$skill};
				print "!" if($fullDB{$fullRace}{$skill} == $bestApt{$skill});
				print "\n";
			} else { print "Only draconians get colours.\n"; next; }
		}
		else
		{
			# checking for invalid arguments
			unless( defined($transRaceDB{$race}) )	{ print "Not a valid race.\n"; next; }
			unless( defined($skillList{$skill}) )	{ print "Not a valid skill.\n"; next; }

			my $fullRace = $transRaceDB{$race};
			print "$race($skill)=", $fullDB{$fullRace}{$skill};
			print "!" if($fullDB{$fullRace}{$skill} == $bestApt{$skill});
			print "\n";
		}
	} # }}}
	else										# $race is defined {{{
	{
		# valid race
		unless( defined($transRaceDB{$race}) )	{ print "Not a valid race.\n"; next; }

		if( defined($colour) ) # -colour=red{{{
		{
			unless($race eq "Dr")					{ print "Only draconians get colours.\n"; next;}
			unless( defined($dracColours{$colour}))	{ print "Not a valid colour.\n"; next; }

			my $fullRace = $dracColours{$colour};
			my %tempDB = %{ $fullDB{$fullRace} };
			my ($ref, @tempVar);

			if( defined($sort) && $sort eq "alpha" ) {
				@tempVar = (sort keys %tempDB);
				$ref = \@tempVar;
			}
			else {
				$ref = \@gameOrder;
			}

			my $output;
			foreach my $k (@$ref)
			{
				my $v = $tempDB{$k};
				unless($k eq "SK_UNUSED_1" || $k eq "undefined")
				{
					$output .= $skillList{$k} . ":" . $v;
					$output .=  "!" if($v == $bestApt{$k});
					$output .=  ", ";
				}
			}
			chop $output; chop $output;
			print "$output\n";
		} # }}}
		else
		{
			# Do reference magic here
			my $fullRace = $transRaceDB{$race};
			my %tempDB = %{ $fullDB{$fullRace} };
			my ($output, $ref, @tempVar);

			if( defined($sort) && $sort eq "alpha" ) {
				@tempVar = (sort keys %tempDB);
				$ref = \@tempVar;
			}
			else {
				$ref = \@gameOrder;
			}
			foreach my $k (@$ref)
			{
				my $v = $tempDB{$k};
				unless($k eq "SK_UNUSED_1" || $k eq "undefined")
				{
					$output .= $skillList{$k} . ":" . $v;
					$output .=  "!" if($v == $bestApt{$k});
					$output .=  ", ";
				}
			}
			chop $output; chop $output;
			print "$output\n";
		}
	} # }}}
}
elsif( defined($skill) )	# only $skill is defined {{{
{
	unless( defined($skillList{$skill}) )	{ print "Not a valid skill.\n"; next; }

	my $output;
	foreach my $k (sort keys %transRaceDB)
	{
		my $v = $transRaceDB{$k};
		$output .= "$k=";
		$output .= $fullDB{$v}{$skill};
		$output .= "!" if($bestApt{$skill}==$fullDB{$v}{$skill});
		$output .= ", ";
	}
	chop $output; chop $output;
	print "$output\n";
} # }}}
else						# !($skill && $race) {{{
{
	print "Neither the s nor the r parameters have been set.\n";
} # }}}
