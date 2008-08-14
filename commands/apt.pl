#!/usr/bin/perl

use strict;
use warnings;

do 'commands/helper.pl';
help("Looks up aptitudes for specified race/skill combination.");

our (%fullDB, %transRaceDB, %skillList, %bestApt, %dracColours);
my %raceMap;

sub buildTransDB # {{{
{
	%dracColours = (red=>"SP_RED_DRACONIAN", white=>"SP_WHITE_DRACONIAN",
					green=>"SP_GREEN_DRACONIAN", yellow=>"SP_YELLOW_DRACONIAN",
					grey=>"SP_GREY_DRACONIAN", black=>"SP_BLACK_DRACONIAN",
					purple=>"SP_PURPLE_DRACONIAN", mottled=>"SP_MOTTLED_DRACONIAN",
					pale=>"SP_PALE_DRACONIAN");
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

	%raceMap = map { (lc, $_) } keys(%transRaceDB);
	$transRaceDB{+lc} = $transRaceDB{$_} for keys %transRaceDB;
	$skillList{+lc} = $skillList{$_} for keys %skillList;
} # }}}
sub parseSkillsFile # {{{
{
	open my $infile, "<", "db.cc";
	my $currRace;
	while(<$infile>)
	{
		# Determine race
		$currRace=$1 if(m#\{\s*// ([A-Z\(\)0-9_]+)#);

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

	$bestApt{+lc} = $bestApt{$_} for keys %bestApt;
	$fullDB{+lc} = $fullDB{$_} for keys %fullDB;
	for my $hash (values %fullDB) {
	   $$hash{+lc} = $$hash{$_} for keys %$hash;
	}
} # }}}

# Prepare DB's
buildTransDB();
parseSkillsFile();

# 3rd argument is the entire command line
$_ = lc($ARGV[2]);
s/^!apt\s+(.*)$/$1/;		# Strip away the !apt part of the string

chomp;
if(/^\s* Dr \[([a-z]*)\] \s+ (SK_[A-Z_0-9]+)/xi)				# !apt Dr[red] SK_SOMETHING {{{
{
	unless($dracColours{$1}) { print "Invalid colour.\n"; next; }
	my $race = $dracColours{$1};
	if( defined($skillList{$2}) )
	{
		print "Dr[$1](@{ [uc $2] })=", $fullDB{$race}{$2};
		print "!" if($fullDB{$race}{$2} == $bestApt{$2});
		print "\n";
	}
	else
	{
		print "Invalid skill.\n";
	}
} # }}}
elsif(/^\s* ([A-Za-z]{2}) \s+ (SK_[A-Z_0-9]+)/xi)			# !apt Sp SK_SOMETHING {{{
{
	unless($transRaceDB{$1}) { print "Invalid race.\n"; next; }
	my $race = $transRaceDB{$1};
	my $abbr = $raceMap{$1};
	if( defined($skillList{$2}) )
	{
		print "$abbr (@{ [ uc $2 ]})=", $fullDB{$race}{$2};
		print "!" if($fullDB{$race}{$2} == $bestApt{$2});
		print "\n";
	}
	else
	{
		print "Invalid skill.\n";
	}
} # }}}
elsif(/^\s* (SK_[A-Z_0-9]+)/xi)				# !apt SK_SOMETHING {{{
{
	unless( defined($skillList{uc $1}) )		# Bad skill
	{
		print "Skill does not exist.\n";
		next;
	}
	my $output;
	my $sk = $1;
	foreach my $k (sort keys %transRaceDB)
	{
	    next unless $k =~ /^[A-Z]/;
		my $v = $transRaceDB{$k};
		$output .= "$k=";
		$output .= $fullDB{$v}{$sk};
		$output .= "!" if($bestApt{$sk}==$fullDB{$v}{$sk});
		$output .= ", ";
	}
	chop $output; chop $output;
	print "$output\n";
} # }}}
elsif(/^\s* Dr \[([a-z]*)\]/xi)				# !apt Dr[red] {{{
{
	unless($dracColours{$1}) { print "Invalid colour.\n"; next; }
	my $race = $dracColours{$1};
	my %tempDB = %{ $fullDB{$race} };
	my $output;
	foreach my $k (sort keys %tempDB)
	{
		next unless $k =~ /^[A-Z]/;
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
} #}}}
elsif(/^\s* ([A-Za-z]{2})/x)						# !apt Sp {{{
{
	unless($transRaceDB{$1}) { print "Invalid race.\n"; next; }
	my $race = $transRaceDB{$1};
	my %tempDB = %{ $fullDB{$race} };
	my $output;

	foreach my $k (sort keys %tempDB)
	{
		next unless $k =~ /^[A-Z]/;
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
} #}}}
