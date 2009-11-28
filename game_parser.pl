#!/usr/bin/perl
use strict;
use warnings;

BEGIN {
  push @INC, 'commands';
}
use Helper qw/demunge_xlogline serialize_time/;

my %adjective_skill_title =
  map(($_ => 1), ('Deadly Accurate', 'Spry', 'Covert', 'Unseen'));

# Uncool words intended to cause offence will be righteously filtered.
my $BANNED_WORDS_FILE = 'banned_words.txt';
my @banned_words;
my $banned_words_modtime;

sub load_banned_words {
  return unless -f $BANNED_WORDS_FILE;
  if (!defined($banned_words_modtime)
      || -M($BANNED_WORDS_FILE) < $banned_words_modtime)
  {
    $banned_words_modtime = -M($BANNED_WORDS_FILE);
    @banned_words = ();
    open my $inf, '<', $BANNED_WORDS_FILE or return;
    while (<$inf>) {
      chomp;
      s/^\s*#.*//;
      next unless /\S/;
      push @banned_words, split();
    }
    close $inf;
    print "Loaded ", scalar(@banned_words), " banned words\n";
  }
}

sub contains_banned_word {
  load_banned_words();
  for my $line (@_) {
    for my $word (@banned_words) {
      return 1 if $line =~ /\Q$word/i;
    }
  }
  return undef;
}

sub game_skill_title
{
  my $game_ref = shift;
  my $title = $game_ref->{title};
  $title = skill_farming($title) if $game_ref->{turn} > 200000;
  return $title;
}

sub skill_farming
{
  my $title = shift;
  if ($adjective_skill_title{$title} || $title =~ /(?:ed|ble|ous)$/) {
    return "$title Farmer";
  } elsif ($title =~ /Crazy /) {
    $title =~ s/Crazy/Crazy Farming/;
    return $title;
  } else {
    return "Farming $title";
  }
}

sub handle_output
{
  my $output = shift;
  my $full_output = shift;

  if ($output =~ s/^\n//)
  {
    $output =~ s/^([^:]*)://;
    my $pre = defined($1) ? $1 : '';
    $output =~ s/:([^:]*)$//;
    my $post = defined($1) ? $1 : '';

    my $g = demunge_xlogline($output);
    my $str = $g->{milestone} ? milestone_string($g, 1) : pretty_print($g);
    $output = $pre . $str . $post;
  }

  $output =~ s/\n.*//s unless $full_output;
  chomp $output;
  return $output;
}

sub format_date {
  my $date = shift;
  $date =~ /^(\d{4})(\d{2})(\d{2})/;
  return $1 . "-" . sprintf("%02d", $2 + 1) . "-" . $3;
}

sub formatted_game_field {
  my ($g, $field) = @_;
  if (grep($_ eq $field, 'end', 'start', 'rend', 'rstart', 'time')) {
    return format_date($$g{$field});
  }
  elsif ($field eq 'dur') {
    return serialize_time($$g{$field});
  }
  else {
    return $$g{$field};
  }
}

sub parse_extras {
  my $game_ref = shift;
  my $extra = '';

  if ($$game_ref{extra}) {
    $extra = "[" . join(";",
                        map("$_=" . formatted_game_field($game_ref, $_),
                            split(/,/, $$game_ref{extra}))) . "] ";
  }
  $extra
}

sub pretty_print
{
  my $game_ref = shift;
  my $extra = parse_extras($game_ref);

  my $loc_string = "";
  my $place = $game_ref->{place};
  my $prep = grep($_ eq $place, qw/Temple Blade Hell/)? "in" : "on";
  $prep = "in" if $game_ref->{ltyp} ne 'D';
  $place = "the $place" if grep($_ eq $place, qw/Temple Abyss/);
  $place = "a Labyrinth" if $place eq 'Lab';
  $place = "a Bazaar" if $place eq 'Bzr';
  $place = "Pandemonium" if $place eq 'Pan';
  $loc_string = " $prep $place";

  $loc_string = "" # For escapes of the dungeon, so it doesn't print the loc
    if $game_ref->{ktyp} eq 'winning' or $game_ref->{ktyp} eq 'leaving';

  my $death_date = " on " . format_date($$game_ref{end});
  my $deathmsg = $game_ref->{vmsg} || $game_ref->{tmsg};
  $deathmsg =~ s/!$//;
  my $title = game_skill_title($game_ref);
  sprintf '%s%s the %s (L%d %s)%s, %s%s%s, with %d point%s after %d turn%s and %s.',
      $extra,
      $game_ref->{name},
	  $title,
      $game_ref->{xl},
      $game_ref->{char},
      $game_ref->{god} ? ", worshipper of $game_ref->{god}" : '',
      $deathmsg,
      $loc_string,
      $death_date,
      $game_ref->{sc},
      $game_ref->{sc} == 1 ? '' : 's',
      $game_ref->{turn},
      $game_ref->{turn} == 1 ? '' : 's',
      serialize_time($game_ref->{dur})
}

sub milestone_string
{
  my ($g, $show_time) = @_;
  my $extra = parse_extras($g);

  my $placestring = " ($g->{place})";
  if ($g->{milestone} eq "escaped from the Abyss!")
  {
    $placestring = "";
  }

  my $ms = $$g{milestone};
  my $turn = $$g{turn};
  $ms =~ s/\.$/ on turn $turn./;

  my $time = format_date($$g{time});
  my $prefix = $show_time? "[" . $time . "] " : '';
  sprintf("$prefix%s%s the %s (L%s %s) %s%s",
          $extra,
          $g->{name},
          game_skill_title($g),
          $g->{xl},
          $g->{char},
          $ms,
          $placestring)
}

1;
