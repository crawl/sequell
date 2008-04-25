#!/usr/bin/perl

use strict;
use warnings;

do 'commands/helper.pl';
help("Script to look up the winner of the current competition.");

our $scoreFile = "/home/crawl/chroot/var/games/crawl03/saves/scores";

our @startDate	= (2006, 11, 5, 23);
our @endDate	= (2009, 1, 1, 1);

our $cls = 'Wanderer';
our $char = 'MuWn';

# our $cls = 'Paladin';
# our $char = '[A-Za-z]+';

our $v = '[0-9\.]+';
our $ktyp = 'winning';

open my $infile, '<', $scoreFile or die 'Unable to open score file.\n';

while(<$infile>)
{
	# Filter out stuff
	my $logEntry = $_;
	if(/v=($v).*?
		name=([a-zA-Z]+).*?
		cls=($cls).*?
		char=($char).*?
		sklev=([0-9]+).*
		title=([a-zA-Z ]+).*?
		start=([0-9]+).*?
		turn=([0-9]+).*?
		sc=([0-9]+).*?
		ktyp=($ktyp).*?
		end=([0-9]+)/x)
	{
		my $v = $1;
		my $name = $2;
		my $cls = $3;
		my $char = $4;
		my $sklev = $5;
		my $title = $6;
		my $gameStart = $7;
		my $turn = $8;
		my $sc = $9;
		my $ktyp = $10;
		my $gameEnd = $11;

		# Check date range
		if( &dateOk($gameStart) && &dateOk($gameEnd))
		{
			if($logEntry =~ /god=([A-Za-z ]+).*/) {
				print "$sc $name ($char) the $title, worshipper of $1 escaped with the Orb after $turn turns.\n";
				exit;
			}
			else {
				print "$sc $name ($char) the $title, escaped with the Orb after $turn turns.\n";
				exit;
			}
		}
	}
}
print "No game matching the criteria.\n";

sub dateOk()	# dateToCheck {{{
{
 	my $dateToCheck = \$_[0];
 	my $year	= substr($_[0], 0, 4);
 	my $month	= substr($_[0], 4, 2);
 	my $day		= substr($_[0], 6, 2);
 	my $hour	= substr($_[0], 8, 2);
 
  	if($year>$startDate[0] || 
  			($year>=$startDate[0] && $month>$startDate[1]) ||
  			($year>=$startDate[0] && $month>=$startDate[1] && $day>$startDate[2]) ||
  			($year>=$startDate[0] && $month>=$startDate[1] && $day>=$startDate[2] && $hour>=$startDate[3]) )
  	{
 		if($year<$endDate[0] || 
 				($year<=$endDate[0] && $month<$endDate[1]) ||
 				($year<=$endDate[0] && $month<=$endDate[1] && $day<$endDate[2]) ||
 				($year<=$endDate[0] && $month<=$endDate[1] && $day<=$endDate[2] && $hour<=$endDate[3]) )
 		{
			return 1;
 		}
		else
		{
			return 0;
		}
 	}
	else
	{
		return 0;
	}
} # }}}
