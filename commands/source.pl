#!/usr/bin/perl
use strict;
use warnings;
use lib "src";
use File::Next;
use Helper;

help("Displays lines from the crawl source. The single argument should be either a filename (relative to the source directory) with an optional line range, or a string to search for as part of a function/#define/vault name. Prepend = to the string to force the search to match exactly.");

# helper functions
sub usage { # {{{
    error "Syntax is '<file>[:<start_line>[-<end_line>]]', or the name of a function/#define/vault";
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
sub scan_line { # {{{
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

    my $start_line;
    my $looking_for = 'function';
    my $paren_level = 0;
    my $fh = open_file $filename;
    while ($_ = next_line $fh) {
        if ($looking_for eq 'function') {
            next unless $partial ? s/((.*)$function)//i :
                                   s/((.*)\b$function\b)//;
            $start_line = $.;
            if ($2 =~ /#define/) {
                undef $start_line;
                next;
            }
            $looking_for = 'openbrace';
            redo;
        }
        elsif ($looking_for eq 'openbrace') {
            $paren_level = scan_line $_, $paren_level;
            if (!defined $paren_level) {
                $looking_for = 'function';
                $paren_level = 0;
                next;
            }
            elsif ($paren_level eq 'found') {
                $looking_for = 'closebrace';
            }
        }
        elsif ($looking_for eq 'closebrace' && $_ =~ /^}/) {
          return ($start_line);
        }
    }

    return;
} # }}}
sub check_define { # {{{
    my ($define, $filename, $partial) = @_;

    my $start_line;
    my $looking_for = 'define';
    my $fh = open_file $filename;
    while ($_ = next_line $fh) {
        if ($looking_for eq 'define') {
            next unless $partial ? s/^(\s*#define\s+\w*$define)//i :
                                   s/^(\s*#define\s+$define\b)//;
            return $.;
        }
    }

    return;
} # }}}
sub check_vault { # {{{
    my ($vault, $filename, $partial) = @_;

    my $start_line;
    my $looking_for = 'name';
    my $fh = open_file $filename;
    while ($_ = next_line $fh) {
        if ($looking_for eq 'name') {
            next unless $partial ? s/^(NAME:\s*\w*$vault)//i :
                                   s/^(NAME:\s*$vault\b)//;
            return $.;
        }
    }

    return;
} # }}}
sub get_function { # {{{
    my ($function, $search_for) = @_;
    my $partial = !($function =~ s/^=//);

    if ($search_for eq 'source' || $search_for eq 'function') {
        my $files = File::Next::files({ descend_filter => sub { 0 },
                                        file_filter    => sub { /\.(?:cc|h)$/ },
                                      }, "$source_dir/source");
        while (defined (my $file = $files->())) {
            my $lines = check_function $function, $file, $partial;
            return $lines, $file if defined $lines;
        }
    }
    if ($search_for eq 'source' || $search_for eq 'cdefine') {
        my $files = File::Next::files({ descend_filter => sub { 0 },
                                        file_filter    => sub { /\.(?:cc|h)$/ },
                                      }, "$source_dir/source");
        while (defined (my $file = $files->())) {
            my $lines = check_define $function, $file, $partial;
            return $lines, $file if defined $lines;
        }
    }
    if ($search_for eq 'source' || $search_for eq 'vault') {
        my $files = File::Next::files({ descend_filter => sub { 1 },
                                        file_filter    => sub { /\.des$/ },
                                      }, "$source_dir/source/dat");
        while (defined (my $file = $files->())) {
            my $lines = check_vault $function, $file, $partial;
            return $lines, $file if defined $lines;
        }
    }
    error "Couldn't find $function in the Crawl source tree";
} # }}}
sub get_file { # {{{
    my ($filename, $start, $end) = @_;

    my $fh = open_file $filename;

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
    $filename =~ s/$source_dir\///;
    chomp $lines if defined $lines;
    print $git_browser_url . '?p=crawl.git;a=blob;f=crawl-ref/' .
      $filename . ';hb=HEAD' . (defined $lines ? '#l' . $lines : "") .
	    "\n";
} # }}}

my ($which) = split ' ', $ARGV[2];
$which =~ s/^!//;
my $cmd = strip_cmdline $ARGV[2], case_sensitive => 1;
my ($filename, $function, $start_line, $end_line, $rest) = parse_cmdline $cmd;
error "Couldn't understand $rest" if $rest;
# Paranoid filename check (sorear)
error "Bad filename: $filename"
  unless !$filename || ($filename =~ m{^[\w/+.-]+$} && $filename !~ /[.][.]/);
usage unless defined $filename || defined $function;

my $lines;
if (defined $function) {
    ($lines, $filename) = get_function $function, $which;
}
else {
    $lines = $start_line;
    $filename = "source/$filename";
}

output $lines, $filename;
