#!/usr/bin/perl
use strict;
use warnings;
use lib 'commands';
use Helper qw/:DEFAULT :roles :races/;

help("Chooses randomly between its (space-separated) arguments. Accepts \@char, \@role, and \@race special arguments.");

my %chars;

# helper functions
sub build_char_options { # {{{
    open my $fh, "$source_dir/source/newgame.cc"
        or error "Couldn't open newgame.cc for reading";
    my $role;
    my @found_races;
    while (<$fh>) {
        if (/_class_allowed\(/ .. /^}/) {
            if (/case (JOB_\w+)/) {
                $role = normalize_role $1;
            }
            elsif (/case (SP_\w+)/) {
                my $race = normalize_race $1;
                $race = 'draconian' if $race eq 'red draconian';
                push @found_races, $race;
            }
            elsif (/return CC_(\w+)/) {
                my $type = lc $1;
                if (@found_races) {
                    for my $race (@found_races) {
                        $chars{$role}{$race} = $type;
                    }
                    @found_races = ();
                }
                else {
                    my @simple_races = (grep(!/draconian/, @races),
                                        'draconian');
                    for my $race (@simple_races) {
                        $chars{$role}{$race} = $type
                            unless exists $chars{$role}{$race};
                    }
                }
            }
        }
    }
} # }}}
sub format_output { # {{{
    "The RNG chooses: " . shift() . ".\n"
} # }}}
sub random_race { # {{{
    my @race_list = (grep(!/draconian/, @races), 'draconian');
    @race_list = map { display_race $_ } @race_list;
    return random_choice(@race_list);
} # }}}
sub random_role { # {{{
    my @role_list = map { display_role $_ } @roles;
    return random_choice(@role_list);
} # }}}
sub random_char { # {{{
    my %args = @_;
    my ($race, $role);
    {
        ($race, $role) = ($args{race}, $args{role});
        $race = lc random_race unless defined $race;
        $role = lc random_role unless defined $role;
        redo if $chars{$role}{$race} eq 'banned';
        if (exists $args{good}) {
            if ($args{good}) {
                redo if $chars{$role}{$race} eq 'restricted';
            }
            else {
                redo if $chars{$role}{$race} eq 'unrestricted';
            }
        }
    }
    return short_race($race) . short_role($role);
} # }}}
sub special_choice { # {{{
    my $special = shift;
    build_char_options;
    return random_race if $special eq '@race';
    return random_role if $special eq '@role';
    return $special
        unless $special =~ /\@(good|bad)?(char|race|role)(?:=(.*))?/;
    return $special if defined $3 && $2 eq 'char';
    my %args = ();
    $args{good} = 1 if defined $1 && $1 eq 'good';
    $args{good} = 0 if defined $1 && $1 eq 'bad';
    $args{role} = normalize_role $3 if $2 eq 'role';
    $args{race} = normalize_race $3 if $2 eq 'race';
    return $special if exists $args{role} && !defined $args{role};
    return $special if exists $args{race} && !defined $args{race};
    return random_char %args;
} # }}}
sub random_choice { # {{{
    $_[int rand @_]
} # }}}

my @words = split ' ', strip_cmdline $ARGV[2], case_sensitive => 1;
if (@words == 1) {
    print format_output special_choice @words;
}
else {
    print format_output random_choice @words;
}
