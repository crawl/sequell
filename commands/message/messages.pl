#!/usr/bin/perl
use strict;
use warnings;

do 'commands/message/helper.pl';
use lib 'src';
use Helper qw/demunge_xlogline/;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

my $nick = $ARGV[1];
my $handle = message_handle($nick, '<', "No messages for $nick.");

# print the first message
my $message = <$handle>;
chomp $message;
my $message_ref = demunge_xlogline($message);

# remove the first message from the file
my @rest = <$handle>;
close $handle;

# any more messages?
if (@rest && $rest[0] =~ /:/)
{
  my $handle = message_handle($nick, '>', "Unable to truncate $nick\'s message list: $!.");
  print {$handle} @rest;
}
else
{
  message_clear($nick);
}

printf '(1/%d) %s said (%s ago): %s%s',
  1 + @rest,
  $message_ref->{from},
  serialize_time(time - $message_ref->{time}, 1),
  $message_ref->{msg},
  "\n";
