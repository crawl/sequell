#!/usr/bin/perl
use strict;
use warnings;
use lib 'commands';
use Helper qw/help error strip_cmdline $source_dir/;;

help("Displays lines from the crawl source.");

# helper functions
sub usage { # {{{
    error "Syntax is '<file>[:<start_line>[-<end_line>]]' or '[file:]<function_name>'";
} # }}}
sub parse_cmdline { # {{{
    my $cmd = shift;
    my ($filename, $function, $start_line, $end_line);

    if ($cmd =~ s/^(.*\.[^:]*):?//) {
        $filename = $1;
    }

    if ($cmd =~ s/^(\d+)(?:-(\d+))?//) {
        ($start_line, $end_line) = ($1, $2);
        $end_line = $start_line unless defined $end_line;
        error "Start line must be before end line" if $end_line < $start_line;
    }
    elsif ($cmd =~ s/^(\w+(?:::\w+)*)//) {
        $function = $1;
    }

    return ($filename, $function, $start_line, $end_line, $cmd);
} # }}}
sub check_line { # {{{
    my ($line, $paren_level) = @_;
    for my $char (split //, $line) {
        return if $char eq ';' || $char eq '}';
        $paren_level++ if $char eq '(';
        $paren_level-- if $char eq ')';
        return if $paren_level < 0;
        return "found" if $char eq '{';
    }
    return $paren_level;
} # }}}
sub check_function { # {{{
    my ($function, $filename) = @_;

    open my $fh, "<", $filename
        or error "Couldn't open $filename for reading";

    my $lines;
    my $looking_for = 'function';
    my $paren_level = 0;
    my $in_comment = 0;
    while (<$fh>) {
        if ($in_comment) {
            if (s/.*\*\///) {
                $in_comment = 0;
                redo;
            }
            else {
                next;
            }
        }
        s/\/\/.*//;
        if (s/\/\*.*//) {
            $in_comment = 1;
        }

        if ($looking_for eq 'function') {
            next unless s/((.*)\b$function\b)//;
            $looking_for = 'openbrace';
            $lines = $1;
            redo;
        }
        elsif ($looking_for eq 'openbrace') {
            $paren_level = check_line $_, $paren_level;
            if (!defined $paren_level) {
                $looking_for = 'function';
                $paren_level = 0;
                next;
            }
            elsif ($paren_level eq 'found') {
                $looking_for = 'closebrace';
            }
            $lines .= $_;
        }
        elsif ($looking_for eq 'closebrace') {
            $lines .= $_;
            if (/^}/) {
                close $fh;
                return $lines;
            }
        }
    }

    close $fh;
    return;
} # }}}
sub get_function { # {{{
    my ($function, $filename) = @_;

    if ($filename) {
        my $lines = check_function $function, $filename;
        error "Couldn't find function $function in $filename"
            unless defined $lines;
        return $lines, $filename;
    }
    else {
        require File::Next;
        my $files = File::Next::files("$source_dir/source");
        while (defined (my $file = $files->())) {
            next unless $file =~ /\.cc$/;
            my $lines = check_function $function, $file;
            return $lines, $file if defined $lines;
        }
        error "Couldn't find function $function in the Crawl source tree";
    }
} # }}}
sub get_file { # {{{
    my ($filename, $start, $end) = @_;

    open my $fh, "<", "$source_dir/source/$filename"
        or error "Couldn't open $filename for reading";

    my $lines = '';
    if (defined $start && defined $end) {
        while (<$fh>) {
            $lines .= $_ if $start == $. .. $end == $.;
        }
    }
    else {
        $lines = do { local $/; <$fh> };
    }

    return $lines;
} # }}}
sub output { # {{{
    my ($lines, $filename) = @_;

    chomp $lines;
    if ($lines =~ /\n/) {
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
        print "$lines\n";
    }
} # }}}

my $cmd = strip_cmdline $ARGV[2], case_sensitive => 1;
my ($filename, $function, $start_line, $end_line, $rest) = parse_cmdline $cmd;
error "Couldn't understand $rest" if $rest;
usage unless defined $filename || defined $function;

my $lines;
if (defined $function) {
    ($lines, $filename) = get_function $function, $filename;
}
else {
    $lines = get_file $filename, $start_line, $end_line;
}

output $lines, $filename;
