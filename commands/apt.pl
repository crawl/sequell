#!/usr/bin/perl
use strict;
use warnings;
use lib 'commands';
use Helper qw/:DEFAULT :skills :races/;

help("Looks up aptitudes for specified race/skill combination.");

my %apts;

# helper functions
sub parse_apt_file { # {{{
    my %apts;
    my $aptfile = shift;
    open(my $fh, '<', $aptfile) or error "Couldn't open $aptfile for reading";
    my $race;
    while (<$fh>) {
        if (/^\s*APT\(\s*(\w+)\s*,\s*(\w+)\s*,\s*(-?\d+)/) {
            my ($raw_race, $raw_aptname, $raw_aptvalue) = ($1, $2, $3);
            $race = normalize_race($raw_race);
            my $apt = $raw_aptvalue;
            my $skill = normalize_skill($raw_aptname);
            $apts{$race}{$skill} = $apt;
        }
    }
    close $fh;
    return %apts;
} # }}}
sub add_extra_apts { # {{{
    my $aptref = shift;
    my %apts = %{ $aptref };
    my $aptfile = shift;
    open(my $fh, '<', $aptfile) or error "Couldn't open $aptfile for reading";
    my (@races, $genus);
    while (<$fh>) {
        if (/int species_exp_modifier\(/ .. /^}/) {
            if (/(GENPC_\w+)/) {
                @races = genus_to_races($1);
            }
            elsif (/(SP_\w+)/) {
                push @races, normalize_race($1);
            }
            elsif (/return (\d+);/) {
                for my $race (@races) {
                    $apts{$race}{experience} = $1 * 10;
                    $apts{$race}{hp} = 0;
                    $apts{$race}{mp} = 0;
                }
                @races = ();
            }
        }
        if (/int species_hp_modifier\(/ .. /^}/) {
            if (/(GENPC_\w+)/) {
                @races = genus_to_races($1);
            }
            if (/(SP_\w+)/) {
                push @races, normalize_race($1);
            }
            elsif (/return (-?\d+);/) {
                for my $race (@races) {
                    $apts{$race}{hp} = $1;
                }
                @races = ();
            }
        }
        if (/int species_mp_modifier\(/ .. /^}/) {
            if (/(GENPC_\w+)/) {
                @races = genus_to_races($1);
            }
            if (/(SP_\w+)/) {
                push @races, normalize_race($1);
            }
            elsif (/return (-?\d+);/) {
                for my $race (@races) {
                    $apts{$race}{mp} = $1;
                }
                @races = ();
            }
        }
    }
    close $fh;
    return %apts;
} # }}}

sub skill_is_better($$$) {
  my ($skill, $ra, $rb) = @_;

  my $a = $apts{$ra};
  my $b = $apts{$rb};

  my $va = $a->{$skill};
  my $vb = $b->{$skill};
  warn "No $skill for $ra\n" unless defined $va;
  warn "No $skill for $rb\n" unless defined $vb;
  return ($skill eq 'experience'? $va < $vb : $va > $vb);
}

sub is_best_apt { # {{{
    my ($race, $skill) = @_;
    return 0 unless $race && $skill;
    for (@races) {
      no warnings 'uninitialized';
      return 0 if skill_is_better($skill, $_, $race);
    }
    return 1;
} # }}}
sub is_worst_apt { # {{{
    my ($race, $skill) = @_;
    return 0 unless $race && $skill;
    for (@races) {
      no warnings 'uninitialized';
      return 0 if skill_is_better($skill, $race, $_);
    }
    return 1;
} # }}}
sub apt { # {{{
    my ($race, $skill) = @_;
    return "?" unless $race && $skill;
    return $apts{$race}{$skill} . (is_best_apt($race, $skill) ? "!" :
                                   is_worst_apt($race, $skill) ? "*" : "");
} # }}}
sub check_long_option { # {{{
    my $word = shift;
    $word =~ /-?(.*?)=(.*)/;
    my ($option, $val) = ($1, $2);
    return unless defined $option && defined $val;
    $val = lc $val;

    if ((substr $option, 0, 2) eq 'so') {
        return ('sort', $val);
    }
    elsif ((substr $option, 0, 1) eq 's') {
        return ('skill', normalize_skill($val));
    }
    elsif ((substr $option, 0, 1) eq 'r') {
        return ('race', normalize_race($val));
    }
    elsif ((substr $option, 0, 1) eq 'c') {
        return ('color', $val) if is_valid_drac_color $val;
        error "Invalid color: $val";
    }
    else {
        return;
    }
} # }}}
sub print_single_apt { # {{{
    my ($race, $skill) = @_;
    print short_race($race),
          " (", code_skill($skill), ")=",
          apt($race, $skill), "\n";
} # }}}
sub print_race_apt { # {{{
    my ($race, $sort) = @_;
    my @list = @skills;
    @list = sort @list if !defined $sort || $sort eq 'alpha';
    my @out;
    for (@list) {
        push @out, (short_skill $_) . ': ' . (apt $race, $_);
    }
    print short_race($race), ": ", join(', ', @out), "\n";
} # }}}
sub print_skill_apt { # {{{
    my ($skill, $sort) = @_;
    die "No skill name?" unless $skill;
    my @list = @races;
    @list = sort { lc(short_race($a)) cmp lc(short_race($b)) } @list
      if !defined $sort || $sort eq 'alpha';
    my @out;
    for (@list) {
        push @out, (short_race $_) . ': ' . (apt $_, $skill);
    }
    print short_skill($skill), ": ", join(', ', @out), "\n";
} # }}}

# get the aptitudes out of the source file
%apts = parse_apt_file "$source_dir/source/aptitudes.h";
%apts = add_extra_apts \%apts, "$source_dir/source/species.cc";
# get the request
my @words = split ' ', strip_cmdline $ARGV[2];
my @rest;

# loop over the words, checking for things we understand
my %opts;
while (@words) {
    my ($test, $option);

    ($option, $test) = check_long_option $words[0];
    if (defined $test) {
        error "$option already defined with $opts{$option}, but I got $test"
            if exists $opts{$option};
        $opts{$option} = $test;
        shift @words;
        next;
    }

    $test = normalize_race join ' ', @words;
    if (defined $test) {
        error "race already defined with $opts{race}, but I got $test"
            if exists $opts{race};
        $opts{race} = $test;
        @words = @rest;
        @rest = ();
        next;
    }

    $test = normalize_skill join ' ', @words;
    if ($test) {
        error "skill already defined with $opts{skill}, but I got $test"
            if exists $opts{skill};
        $opts{skill} = $test;
        @words = @rest;
        @rest = ();
        next;
    }

    unshift @rest, pop @words;
    if (@words == 0) {
        error "Could not understand \"$rest[0]\"";
    }
}

# check for validity of the color option
if (exists $opts{color}) {
    if (!defined $opts{race} || $opts{race} ne 'base draconian') {
        error "The color option is only valid for draconians";
    }
    $opts{race} = "$opts{color} draconian";
}

# print the result
if (exists $opts{race} && exists $opts{skill}) {
    print_single_apt $opts{race}, $opts{skill}, $opts{sort};
}
elsif (exists $opts{race}) {
    print_race_apt $opts{race}, $opts{sort};
}
elsif (exists $opts{skill}) {
    print_skill_apt $opts{skill}, $opts{sort};
}
else {
    error "You must provide at least a race or a skill";
}
