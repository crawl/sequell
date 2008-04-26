#!/usr/bin/perl
use strict;
use warnings;
do 'commands/helper.pl';

help("Interacts with the learndb. Syntax: !learn query item; !learn (add|del) item text; !learn edit item[num] s/replace-this/with-this/.");

my $subcommand;
my $args;

my %filenames =
(
  query  => "query.pl",

  add    => "add.pl",

  delete => "delete.pl",
  del    => "delete.pl",
  rm     => "delete.pl",

  edit   => "edit.pl",
);

if ($ARGV[2] =~ s/^\?\?(.*)//)
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
$args =~ y/'//d;

exec("commands/learn/$subcommand", $ARGV[1], $args);

