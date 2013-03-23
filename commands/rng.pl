#!/usr/bin/perl
use strict;
use warnings;
use lib "src";
use Helper qw/:DEFAULT :roles :races :gods/;

help("Chooses randomly between its (space-separated) arguments. Accepts \@god, \@char, \@role, and \@race special arguments. Prefixing the special argument with 'good' or 'bad' limits the choices to only unrestricted or only restricted combos, respectively. \@role=<role> or \@race=<race> chooses a random combo with the specified role/race.");

my %chars;

# helper functions

my %CANON_FIELDS = (race => 'sp', role => 'cls', class => 'cls');

sub parse_unwon_options {
  my $text = shift;
  return () unless $text;
  my @frags = split(/;/, $text);
  my %opts;
  parse_unwon_option($_, \%opts) for @frags;
  %opts
}

sub parse_unwon_option {
  my ($opt, $ropt) = @_;
  if ($opt !~ /^\s*(race|sp|cls|role|class|char)\s*(!?=)\s*([a-z]+(?:\|[a-z]+)*)\s*$/) {
    die "Malformed option: $opt\n";
  }

  my ($field, $op, $value) = ($1, $2, $3);
  $field = $CANON_FIELDS{$field} || $field;
  push @{$$ropt{filter_subs}}, unwon_option_filter($field, $op, $value);
}

sub unwon_option_filter {
  my ($field, $op, $value) = @_;
  $value = lc $value;
  my %values;
  my $addval = sub {
      my $val = shift;
      s/^\s+//, s/\s+$// for $val;
      $values{lc $val} = 1;
    };
  if ($value =~ /\|/) {
    $addval->($_) for split /\|/, $value;
  }
  else {
    $addval->($value);
  }
  my $extractor =
    sub {
      return lc($_) if $field eq 'char';
      my ($race, $cls) = /^([a-z]{2})([a-z]{2})/i;
      lc($field eq 'sp' ? $race : $cls)
    };
  my $eq = $op eq '=';
  return sub {
      grep(($eq || 0) == ($values{$extractor->($_)} || 0), @_)
    };
}

sub pick_unwon_combo {
  my %pars = @_;
  my %opts = parse_unwon_options($pars{filter});
  my @unwon = map($_->[0], unwon_combos());
  for my $filter (@{$opts{filter_subs}}) {
    @unwon = $filter->(@unwon);
  }
  return random_choice(@unwon);
}

sub build_char_options { # {{{
    my $char_file = "$source_dir/source/ng-restr.cc";
    open my $fh, '<', $char_file
        or error "Couldn't open $char_file for reading";
    my $role;
    my @found_races;
    while (<$fh>) {
        if (/ job_allowed\(/ .. /^}/) {
            if (/case (JOB_\w+)/) {
                $role = normalize_role($1) || '';
            }
            elsif (/case (SP_\w+)/) {
                my $race = normalize_race $1;
                $race = 'draconian' if $race && $race eq 'red draconian';
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
sub random_god { # {{{
    # [ds] Can't use random_choice, seeing we've gamed that.
    return display_god $gods[int rand @gods];
} # }}}
sub random_char { # {{{
    my %args = @_;
    my ($race, $role);
    {
        ($race, $role) = ($args{race}, $args{role});
        $race = lc random_race unless $race;
        $role = lc random_role unless $role;
        redo if !$role || !$race || $chars{$role}{$race} eq 'banned';
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
# elliot's tweak
    my $special = shift;
    build_char_options;
    if ($special =~ /^([^\d]+)\*(\d+)$/) {
        my $count = $2 > 15 ? 15 : $2;
        my @choices;
        foreach (1..$count) {
            push @choices, special_choice($1);
        }
        return join ' ', @choices;
    }
    return random_race if $special eq '@race';
    return random_role if $special eq '@role';
    return random_god  if $special eq '@god';
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
#    my $special = shift;
#    build_char_options;
#    return random_race if $special eq '@race';
#    return random_role if $special eq '@role';
#    return random_god  if $special eq '@god';
#    return $special
#        unless $special =~ /\@(good|bad)?(char|race|role)(?:=(.*))?/;
#    return $special if defined $3 && $2 eq 'char';
#    my %args = ();
#    $args{good} = 1 if defined $1 && $1 eq 'good';
#    $args{good} = 0 if defined $1 && $1 eq 'bad';
#    $args{role} = normalize_role $3 if $2 eq 'role';
#    $args{race} = normalize_race $3 if $2 eq 'race';
#    return $special if exists $args{role} && !defined $args{role};
#    return $special if exists $args{race} && !defined $args{race};
#    return random_char %args;
} # }}}
sub random_choice { # {{{
    # [ds] Xom IS the RNG!
    die "Nothing to choose from.\n" unless @_;
    my @xoms = grep(/xom/i, @_);
    @xoms ? $xoms[int rand @xoms] : $_[int rand @_]
} # }}}

my @words = split ' ', strip_cmdline $ARGV[2], case_sensitive => 1;
if (@words == 1) {
    print format_output special_choice @words;
}
else {
    print format_output random_choice @words;
}
