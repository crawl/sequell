#!/usr/bin/perl

# use strict;
# use warnings;

do 'commands/helper.pl';

help("Abbreviates race/role abbreviations. Example usage: !ftw Troll Berserker");

sub race_lookup {
	my $key = shift;
	my $i;
	for($i=0; $i<@races; $i++) {
		return $races_abbrev[$i] if ($races[$i] eq $key);
	}
	return '';
}
sub role_lookup {
	my $key = shift;
	my $i;
	for($i=0; $i<@roles; $i++) {
		return $roles_abbrev[$i] if ($roles[$i] eq $key);
	}
	return '';
}

sub ftw {
	my ($word1, $word2, $word3, $word4, $remainder) = split(' ');
	my @keys = ();
	
	push @keys, $word1 unless $word1 eq '';
	push @keys, $word2 unless $word2 eq '';
	push @keys, $word3 unless $word3 eq '';
	push @keys, $word4 unless $word4 eq '';
	push @keys, "$word1 $word2" unless $word2 eq '';
	push @keys, "$word2 $word3" unless $word3 eq '';
	push @keys, "$word3 $word4" unless $word4 eq '';
	
	my $race = '??';
	my $role = '??';
	my $temp_race = '';
	my $temp_role = '';
	foreach(@keys) {
		$temp_race = race_lookup($_);
		$temp_role = role_lookup($_);
		$race = $temp_race if $temp_race ne '';
		$role = $temp_role if $temp_role ne '';
		last if (($race ne '??') and ($role ne '??'));
	}
	return "$race$role";
}

# 3rd argument is the entire command line
$_ = lc($ARGV[2]);
s/^!ftw\s+(.*)$/$1/;

chomp;

print ftw($_);
