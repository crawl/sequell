#!/usr/bin/perl

# use strict;
# use warnings;

do 'commands/helper.pl';
help("Gives an URL to the users last morgue file.");

my $nick = shift;
my $baseURL = "http://crawl.akrasiac.org/rawdata/";
my $localBase = "/var/www/crawl/rawdata/";
my $localPath = $localBase . $nick;

unless (-d $localPath) {
  my @dirs = glob "$localBase/*";
  my ($dir) = grep m{/$nick$}i, @dirs;
  if (-d $dir) {
    $localPath = $dir;
    ($nick) = $dir =~ m{.*/(.*)};
  }
}

unless (-d $localPath) { print "User does not exist.\n"; }
else
{
	# Get files in the directory
	chdir $localPath;
 	my @files = sort (glob "morgue*.txt");

	if( $#files >= 0 )
	{
		my $lastFile = $files[-1];
		print $baseURL . $nick . "/" . $lastFile . "\n";
	}
	else
	{
		print "No morgues file for " . $nick . "\n";
	}
}
