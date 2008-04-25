#!/usr/bin/perl
use strict;
use warnings;
do 'commands/message/helper.pl';

my $nick = shift;

if (my $cnt = message_count($nick))
{
  if (message_notify($nick))
  {
    # just in case their first command is !messages
    exit if $ARGV[0] =~ /^!messages\b/i;

    printf '%s: You have %d message%s. Use !messages to read %s.%s',
           $nick,
           $cnt,
           $cnt == 1 ? '' : 's',
           $cnt == 1 ? 'it' : 'them',
           "\n";
  }
}

