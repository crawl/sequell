#!/usr/bin/perl
use strict;
use warnings;
do 'commands/message/helper.pl';

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
chomp(my @args = <STDIN>);
my $message = $args[2];
$message =~ s/^!tell +//i;
$message =~ /^([a-zA-Z0-9_-]+) +(.+)$/ or do
{
  print "I don't grok. Syntax is !tell PERSON MESSAGE.\n";
  exit;
};

my $to = $1;
$message = $2;

if (length $message > 300)
{
  print "Maximum message length is 300 characters. Eschew verbosity, Gladys!\n";
  exit;
}

my $handle = message_handle($to, '>>', "Unable to add your message to $to\'s queue, sorry!");

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

message_notify($to, 1);
print "$args[1]: OK, I'll let $to know.\n";
