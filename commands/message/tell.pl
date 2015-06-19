#!/usr/bin/perl -CAS
use strict;
use warnings;
use Encode qw/decode/;
use utf8;
use open qw/:std :utf8/;
use lib 'src';
use MessageDB;
use Seen;
use Helper;

chomp(my @args = @ARGV);

sub fail() {
  print "I don't grok. Syntax is !tell PERSON MESSAGE.\n";
  exit;
}

Helper::forbid_proxying();

my $message = $args[2];
$message =~ s/^\S+ +//i;
$message =~ /^(\S+) +(.+)$/ or fail();

my $to = MessageDB::cleanse_nick($1) or fail;

if (!Seen::seen($to)) {
  print "Sorry $ARGV[1], I don't know who $to is.\n";
  exit 1;
}

$message = $2;

if (length $message > 300)
{
  printf "Maximum message length is 300 characters, but you had %d. ",
         length $message;
  print "Eschew verbosity, Gladys!\n";
  exit;
}

my $handle = MessageDB::handle($to, '>>', "Unable to add your message to $to\'s queue, sorry!");

my %message =
(
  from => $args[1],
  to => $to,
  msg => $message,
  time => time,
);

print {$handle} join(':',
                     map {$message{$_} =~ s/:/::/g; "$_=$message{$_}"}
                     keys %message),
                "\n" or do
{
  print "Unable to add your message to $to\'s queue, sorry!\n";
  die "Unable to print to message_dir/$to: $!";
};

MessageDB::notify($to, 1);
print "$args[1]: OK, I'll let $to know.\n";
