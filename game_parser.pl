#!/usr/bin/perl
use strict;
use warnings;

BEGIN {
  push @INC, 'commands';
}
use Helper qw/demunge_xlogline serialize_time/;

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
    my $str = exists($g->{mtype}) ? milestone_string($g, 1) : pretty_print($g);
    $output = $pre . $str . $post;
  }

  $output =~ s/\n.*//s unless $full_output;
  chomp $output;
  return $output;
}

sub format_date {
  my $date = shift;
  $date =~ /^(\d{4})(\d{2})(\d{2})/;
  $date
}

sub formatted_game_field {
  my ($g, $field) = @_;
  if (grep($_ eq $field, 'endtime', 'starttime', 'currenttime')) {
    return format_date($$g{$field}) . " [$$g{$field}]";
  }
  elsif ($field eq 'realtime') {
    return serialize_time($$g{$field}) . " [$$g{$field}]";
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

sub game_place($) {
  my $g = shift;

  my $place = $$g{place};
  return '' unless $place;

  my $prep = $place =~ /:/? 'on' : 'in';
  " $prep $place"
}

sub game_title($) {
  my $g = shift;
  my @items = grep($_, map($$g{$_}, qw/role race align gender/));
  join(" ", @items)
}

sub pluralize($$) {
  my ($n, $thing) = @_;
  "$n " . ($n == 1? $thing : "${thing}s")
}

sub pretty_date_time($) {
  my $rawdate = shift;
  if ($rawdate =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/) {
    return "$1-$2-$3 $4:$5:$6";
  }
  $rawdate
}

sub pretty_print
{
  my $g = shift;

  my $extra_fields = parse_extras($g);
  my $name = $$g{name};
  my $title = game_title($g);
  $title = " ($title)" if $title;
  my $place = game_place($g);
  my $dur = serialize_time($$g{realtime});
  my $time = pretty_date_time($$g{endtime});

  my $points = pluralize($$g{points}, "point");
  my $turns  = pluralize($$g{turns}, "turn");

  my $durbyturns = ($$g{turns} > 0? serialize_time($$g{realtime} / $$g{turns})
                    : '');
  $durbyturns = "; $durbyturns per turn" if $durbyturns;

  "$extra_fields$name$title $$g{death}$place with $points on $time after " .
    "$turns ($dur$durbyturns)"
}

sub milestone_string($$) {
  my ($g, $show_time) = @_;

  my $extra_fields = parse_extras($g);

  my $name = $$g{name};
  my $title = game_title($g);
  $title = " ($title)" if $title;
  my $place = game_place($g);
  my $dur = serialize_time($$g{realtime});
  my $time = $$g{deathtime};


  my @extras;
  push @extras, "T:$$g{turns}" if $$g{turns};
  push @extras, "time:" . serialize_time($$g{realtime}) if $$g{realtime};

  my $extra = '';
  $extra = " (" . join(", ", @extras) . ")" if @extras;

  "$extra_fields$name$title $$g{mdesc}$extra"
}

1;
