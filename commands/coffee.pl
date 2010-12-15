#! /usr/bin/env perl

use strict;
use warnings;

use lib 'commands';
use Helper;
use utf8;

binmode STDOUT, ':utf8';
help("Brews a delicious mug of coffee!");

my $nick = shift;

my @coffee_basetypes =
  ("black coffee",
   "cappuccino",
   "irish coffee",
   "café au lait",
   "soy latte",
   "caffè macchiato",
   "latte macchiato",
   "caffè breve",
   "café mocha"
  );

my @brewers =
  (
   'Sigmund',
   'Ijyb',
   'Xtahua',
   'Gastronok',
   'Cerebov',
   'Crazy Yiuf',
   'Snorg',
   'the Serpent of Hell',
   'Mnoleg',
   'Trog',
   'Jiyva',
   'Xom',
   'Makhleb',
   'Kikubaaqudgha',
   'Yredelemnul'
  );

my @containers =
  (
   'cup',
   'mug',
   'pot',
   { wt => 20, name => 'barrel' },
   { wt => 1, name => 'supertanker' }
  );

my $coffee = do_coffee();
print "/me hands $nick $coffee.";

sub random_from {
  my $chosen;
  my $weight = 0;
  for my $thing (@_) {
    my $thisweight = 100;
    my $this = $thing;
    if (ref($thing) eq 'HASH') {
      $thisweight = $thing->{wt};
      $this = $thing->{name};
    }
    $chosen = $this if int(rand($weight += $thisweight)) < $thisweight;
  }
  return $chosen;
}

sub do_coffee {
  my $coffee_kind = random_from(@coffee_basetypes);
  my $brewer = random_from(@brewers);
  my $need_container = $coffee_kind !~ /^an? /;
  if ($need_container) {
    my $container = random_from(@containers);
    return "a $container of $coffee_kind, brewed by $brewer";
  } else {
    return "$coffee_kind, brewed by $brewer";
  }
}
