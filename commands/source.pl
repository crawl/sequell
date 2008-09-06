#!/usr/bin/perl
use strict;
use warnings;
use lib 'commands';
use Helper qw/help error strip_cmdline $source_dir/;;

help("Displays lines from the crawl source.");

sub usage {
    error "Syntax is 'file:lines'";
}

my @words = split ':', strip_cmdline $ARGV[2];
usage if @words > 2 || @words == 0;

my ($filename, $linenos) = @words;
open my $fh, "<", "$source_dir/source/$filename"
    or error "Couldn't open $filename for reading";

my $multiline = 1;
my $lines = '';
if (defined $linenos) {
    my ($start_line, $end_line) = split '-', $linenos;
    if (!defined $end_line) {
        $end_line = $start_line;
        $multiline = 0;
    }
    usage if $start_line == 0 || $end_line == 0;
    error "End line cannot be before start line" if $end_line < $start_line;
    while (<$fh>) {
        $lines .= $_ if $start_line == $. .. $end_line == $.;
    }
}
else {
    $lines = do { local $/; <$fh> };
}

if ($multiline) {
    my $lang = 'text';
    $lang = 'cpp'    if $filename =~ /\.(?:cc|h)$/;
    $lang = 'python' if $filename =~ /\.py$/;
    $lang = 'lua'    if $filename =~ /\.lua$/;
    require App::Nopaste;
    my $url = App::Nopaste::nopaste(text => $lines,
                                    nick => $ARGV[1],
                                    lang => $lang);
    print "Lines pasted to $url\n";
}
else {
    print "$lines";
}
