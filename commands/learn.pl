#!/usr/bin/perl
use strict;
use warnings;

use lib 'src';
use Helper;

help("Learndb. Syntax: !learn query item; !learn (add|del) item text; !learn edit item[num] s/replace-this/with-this/; !learn swap a b; !learn mv a b");

my $subcommand;
my $args;

my %filenames =
(
  query  => "query.pl",
  q      => "query.pl",

  add    => "add.pl",
  a      => "add.pl",
  insert => 'add.pl',

  mv     => 'move.pl',
  move   => 'move.pl',

  delete => "delete.pl",
  del    => "delete.pl",
  rm     => "delete.pl",

  edit   => "edit.pl",
  e      => "edit.pl",

  swap   => "swap.pl",
);

if ($ARGV[2] =~ s/^\?[?>](.*)//)
{
  $subcommand = "query";
  $args = $1;
}
elsif ($ARGV[2] =~ s/^!learn +(\w+) *(.*)$//i)
{
  $subcommand = $1;
  $args = $2;
}

if (!defined($subcommand))
{
  print "I don't get what you mean..";
  exit;
}

if (!exists $filenames{$subcommand})
{
  print "I don't know about !learn $subcommand.";
  exit;
}

$subcommand = $filenames{$subcommand};
$args = '' unless defined $args;

exec("commands/learn/$subcommand", $ARGV[1], $args);
