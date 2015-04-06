#!/usr/bin/perl
use strict;
use warnings;
use lib "src";
use File::Next;
use File::Basename qw//;
use Helper;

help("Displays lines from the crawl source. The single argument should be either a filename (relative to the source directory) with an optional line range, or a string to search for as part of a function/#define/vault name.");

# helper functions
sub usage { # {{{
    error "Syntax is '<file>[:<start_line>[-<end_line>]]', or the name of a function/#define/vault";
} # }}}
sub parse_cmdline { # {{{
    my $cmd = shift;
    my ($filename, $function, $start_line, $end_line);

    my $nth;
    if ($cmd =~ s/\s+(\d+)$//) {
      $nth = $1;
    }

    if ($cmd =~ s{^([\w/.-]+)(?::(\d+)(?:-(\d+))?)?(?= |$)}{}) {
        $filename = $1;
        s/\.$// for $filename;
        $start_line = $2;
        $end_line = $3;
    }

    my $fnregex = qr/^(~?[*\w]+(?:::~?\w+)*$)/;
    if ($cmd =~ s/^(\d+)(?:-(\d+))?//) {
        ($start_line, $end_line) = ($1, $2);
        $end_line = $start_line unless defined $end_line;
        error "Start line must be before end line" if $end_line < $start_line;
    }
    elsif ($cmd =~ s/$fnregex// || $filename =~ /$fnregex/) {
        $function = $1;
    }

    return ($filename, $function, $start_line || $nth, $end_line, $cmd);
}

sub output {
    my (%result) = @_;
    my $filename = $result{file};
    $filename =~ s/$source_dir\///;
    my $lines = $result{line};
    chomp $lines if defined $lines;

    my $prefix = '';
    if ($result{n} && $result{total}) {
      $prefix = "$result{n}/$result{total}. ";
    }

    print $prefix . $Helper::GIT_BROWSER_URL .
      $filename . (defined $lines ? '#l' . $lines : "") .
	    "\n";
} # }}}

sub find_file_relative {
  my ($root, $pattern) = @_;
  my $files = File::Next::files($root);
  my $lcpattern = lc $pattern;
  while (my $file = $files->()) {
    my $base = File::Basename::basename($file);
    if (lc($base) eq $lcpattern) {
      $file =~ s{^\Q$root/*}{};
      return $file;
    }
  }
  undef
}

sub get_function {
  my ($name, $nth) = @_;
  my $fuzzy = $name =~ /\*/;
  my ($tag, $n, $total) = find_tag("$source_dir/tags", $name, $fuzzy, $nth);
  return unless $tag;
  (lookup_tag_line($source_dir, $tag), n => $n, total => $total)
}

sub lookup_tag_line {
  my ($source_dir, $tag) = @_;
  return unless $tag;
  my $file = "$source_dir/" . $$tag{file};
  open my $inf, '<', $file or return;
  while (<$inf>) {
    if (index($_, $$tag{pattern}) == 0) {
      return (line => $., file => $$tag{file});
    }
  }
  return;
}

sub find_tag {
  my ($tags_file, $tag, $fuzzy, $nth) = @_;
  my @matches = tag_matches($tags_file, $tag, $fuzzy);
  return unless @matches;
  $nth ||= 1;
  $nth--;
  $nth = 0 if $nth < 0;
  $nth = $nth % @matches;
  ($matches[$nth], $nth + 1, scalar(@matches))
}

sub cleanse_tag_pattern {
  for (@_) {
    s{^/\^}{};
    s{\$?/;"$}{};
    s{\\(.)}{$1}g;
    return $_;
  }
}

sub parse_tag_line {
  for (@_) {
    my @parts = split /\t/, $_;
    return +{
      tag => $parts[0],
      file => $parts[1],
      pattern => cleanse_tag_pattern($parts[2])
    }
  }
}

sub tag_line_match {
  my ($tag, $search, $fuzzy) = @_;
  $tag->{tag} =~ /^$search$/
}

sub search_re {
  my ($search, $fuzzy) = @_;
  if ($fuzzy) {
    $search =~ s/\*+/\\w+/g;
    return qr/^$search\t/;
  } else {
    return qr/^\Q$search\E\t/;
  }
}

sub tag_matches {
  my ($tags_file, $search, $fuzzy) = @_;

  my $re = search_re($search, $fuzzy);
  my @matches;
  open my $tf, '<', $tags_file or return @matches;
  # Dumb linear search:
  my $didmatch;
  while (my $line = <$tf>) {
    next if $line =~ /^!/;

    my $match = $line =~ $re;
    last if $didmatch && !$match && !$fuzzy;
    if ($match) {
      $didmatch = 1;
      push @matches, parse_tag_line($line);
    }
  }
  @matches
}

my ($which) = split ' ', $ARGV[2];
$which =~ s/^!//;
my $cmd = strip_cmdline $ARGV[2], case_sensitive => 1;
my ($filename, $function, $start_line, $end_line, $rest) = parse_cmdline $cmd;
$function .= $rest if $rest;
# Paranoid filename check (sorear)
error "Bad filename: $filename"
  unless !$filename || ($filename =~ m{^[\w/+.-]+$} && $filename !~ /[.][.]/);
usage unless defined $filename || defined $function;

my $lines;
my %result;
if (defined $function) {
  %result = get_function $function, $start_line;
  if ((!%result || !$result{file}) && !$filename) {
    error "Can't find $function.";
  }
}

if ((!%result || !$result{file}) && $filename) {
    $result{line} = $start_line;
    if (-f "$source_dir/source/$filename") {
      $result{file} = "source/$filename";
    } else {
      my $found = find_file_relative($source_dir, $filename)
        or error "Can't find $filename.";
      $result{file} = $found;
    }
}

output %result;
