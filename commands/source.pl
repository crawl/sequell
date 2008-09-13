#!/usr/bin/perl
use strict;
use warnings;
use lib 'commands';
use Helper qw/help error strip_cmdline $source_dir/;

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
{ # closure to handle parsing out comments {{{
my $in_comment = 0;
my $filetype = '';
sub open_file { # {{{
    my ($path) = @_;
    open my $fh, '<', $path or error "Couldn't open $path for reading";
    $in_comment = 0;
    ($filetype) = $path =~ /.*\.(\w+)/;
    return $fh;
} # }}}
sub next_line_c { # {{{
    my ($fh) = @_;
    my $line;
    while ($line = <$fh>) {
        if ($in_comment) {
            if ($line =~ s/.*?\*\///) {
                $in_comment = 0;
                redo;
            }
            else {
                next;
            }
        }
        else {
            if ($line =~ s/\/\*.*?(\*\/)?/defined $1 ? $1 : ''/e) {
                $in_comment = defined $1;
                redo;
            }
            $line =~ s/\/\/.*//;
        }
        return $line;
    }
    return;
} # }}}
sub next_line_des { # {{{
    my ($fh) = @_;
    my $line;
    while ($line = <$fh>) {
        next if $line =~ /^#/;
        $line =~ s/#.*//;
        return $line;
    }
    return;
} # }}}
sub next_line { # {{{
    return next_line_c @_ if $filetype eq 'cc' || $filetype eq 'h';
    return next_line_des @_ if $filetype eq 'des';
    return;
} # }}}
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
    my ($function, $filename, $partial) = @_;

    my $lines;
    my $looking_for = 'function';
    my $paren_level = 0;
    my $fh = open_file $filename;
    while ($_ = next_line $fh) {
        if ($looking_for eq 'function') {
            next unless $partial ? s/((.*)$function)// :
                                   s/((.*)\b$function\b)//;
            $lines = $1;
            if ($2 =~ /#define/) {
                $_ = $lines . $_;
                undef $lines;
                next;
            }
            $looking_for = 'openbrace';
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
            return $lines if /^}/;
        }
    }

    return;
} # }}}
sub check_define { # {{{
    my ($define, $filename, $partial) = @_;

    my $lines;
    my $looking_for = 'define';
    my $fh = open_file $filename;
    while ($_ = next_line $fh) {
        if ($looking_for eq 'define') {
            next unless $partial ? s/^(\s*#define\s+\w*$define)// :
                                   s/^(\s*#define\s+$define\b)//;
            $lines = $1;
            $looking_for = 'enddefine';
            redo;
        }
        elsif ($looking_for eq 'enddefine') {
            $lines .= $_;
            return $lines unless $lines =~ /\\\n$/;
        }
    }

    return;
} # }}}
sub check_vault { # {{{
    my ($vault, $filename, $partial) = @_;

    my $lines;
    my $looking_for = 'name';
    my $fh = open_file $filename;
    while ($_ = next_line $fh) {
        if ($looking_for eq 'name') {
            next unless $partial ? s/^(NAME:\s*\w*$vault)// : 
                                   s/^(NAME:\s*$vault\b)//;
            $lines = $1;
            $looking_for = 'endmap';
            redo;
        }
        elsif ($looking_for eq 'endmap') {
            $lines .= $_;
            return $lines if /^ENDMAP/;
        }
    }

    return;
} # }}}
sub get_function { # {{{
    my ($function, $filename) = @_;

    if ($filename) {
        my $lines = check_function $function, $filename;
        error "Couldn't find $function in $filename"
            unless defined $lines;
        return $lines, $filename;
    }
    else {
        require File::Next;
        my $files = File::Next::files("$source_dir/source");
        while (defined (my $file = $files->())) {
            my $lines;
            $lines = check_function $function, $file
                if !defined $lines && $file =~ /\.(?:cc|h)$/;
            $lines = check_define $function, $file
                if !defined $lines && $file =~ /\.(?:cc|h)$/;
            $lines = check_vault $function, $file
                if !defined $lines && $file =~ /\.(?:des)$/;
            $lines = check_function $function, $file, 1
                if !defined $lines && $file =~ /\.(?:cc|h)$/;
            $lines = check_define $function, $file, 1
                if !defined $lines && $file =~ /\.(?:cc|h)$/;
            $lines = check_vault $function, $file, 1
                if !defined $lines && $file =~ /\.(?:des)$/;
            return $lines, $file if defined $lines;
        }
        error "Couldn't find $function in the Crawl source tree";
    }
} # }}}
sub get_file { # {{{
    my ($filename, $start, $end) = @_;

    my $fh = open_file "$source_dir/source/$filename";

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
