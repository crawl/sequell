#!/usr/bin/perl

use strict;
use warnings;

use lib 'commands';
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
	my ($word1, $word2, $word3, $word4, $remainder) = split(' ');
	my @keys = ();

	push @keys, "$word1 $word2" unless !$word2;
	push @keys, "$word2 $word3" unless !$word3;
	push @keys, "$word3 $word4" unless !$word4;
	push @keys, $word1 unless !$word1;
	push @keys, $word2 unless !$word2;
	push @keys, $word3 unless !$word3;
	push @keys, $word4 unless !$word4;

	my $race = '';
	my $role = '';
	my $temp_race = '';
	my $temp_role = '';
	foreach(@keys) {
		$race ||= race_lookup($_);
		$role ||= role_lookup($_);
		last if $race and $role;
	}
    $race ||= '??';
    $role ||= '??';
	return "$race$role";
}

# 3rd argument is the entire command line
$_ = lc($ARGV[2]);
s/^!ftw\s+(.*)$/$1/;

chomp;

print ftw($_);
