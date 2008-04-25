#!/usr/bin/perl

use strict;
use warnings;

my $baseURL='http://crawl.develz.org/cgi-bin/crawl_active_players.sh';
my $columns=200;
my $output="";
my $numPlayers=0;

# do 'commands/helper.pl';
# help("Shows what players are online and playing on CDO.");

# Get dump from the cgi script
$_ = `lynx -width $columns -dump $baseURL`;
my @arr = split /\n/;

foreach (@arr)
{
	# 	(L5 DSCK), a worshipper of Xom, is currently on D:4 after 5027 turns.
	if(/^\s* ([0-9a-zA-Z_]+) \s* \((L[0-9]+) \s* ([A-Za-z]+) \) .* currently \s [io]n \s ([A-Za-z:0-9]+) \s after \s ([0-9]+) .*/x)
	{
		$numPlayers++;
		$output .= "$1 ($2 $3 \@ $4, T:$5), ";
	}
}

# Fix the final output and print it
$output = "$numPlayers players: $output";
chop $output; chop $output;
print $output, "\n";
