#!/usr/bin/perl

use strict;
use warnings;

use lib "src";
use Helper qw/short_race short_role/;

Helper::help("Abbreviates race/role abbreviations. " .
             "Example usage: !ftw Troll Berserker");

sub race_lookup {
	my $key = lc(shift);
    my $abbr = short_race($key) || '';
    # Discard draconian qualifiers:
    $abbr =~ s/\[.*?\]// if $abbr;
    $abbr
  }
sub role_lookup {
	my $key = lc(shift);
        return short_role($key) || '';
}

sub ftw {
	my @words = split(' ');

	# Look for a pivot point to split the arguments in 2 groups
	# Return if the groups match a race AND a role.
	for (my $i = 0; $i <= $#words - 1; $i++) {
		my $first = join(" ", @words[0..$i]);
		my $second = join(" ", @words[$i+1..$#words]);

		my $race = race_lookup($first);
		my $role = role_lookup($second);
		return "$race$role" if $race and $role;

		# reverse them
		$race = race_lookup($second);
		$role = role_lookup($first);
		return "$race$role" if $race and $role;
	}

	# The strict version didn't work so we will relax the rules a bit and look
	# for only 1 match. We take more words on both ends until a match is found.
	for (my $i = 0; $i <= $#words; $i++) {
		my $head = join(" ", @words[0..$i]);
		my $tail = join(" ", @words[$#words - $i .. $#words]);
		my $race = race_lookup($head) || race_lookup($tail);
		my $role = role_lookup($head) || role_lookup($tail);
		return "$race??" if $race;
		return "??$role" if $role;
	}

	return "????";
}

# 3rd argument is the entire command line
$_ = lc($ARGV[2]);
s/^!ftw\s+(.*)$/$1/;

chomp;

print ftw($_);
