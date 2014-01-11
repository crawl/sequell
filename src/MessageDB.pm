package MessageDB;

use strict;
use warnings;

use lib 'src';
use Helper;
use Henzell::IRCUtil;
use File::Path;
use open qw/:std :utf8/;

our $message_dir = 'dat/messages';

sub cleanse_nick
{
  Henzell::IRCUtil::cleanse_nick(shift())
}

sub count
{
  my $nick = cleanse_nick(shift);
  open my $handle, '<', "$message_dir/$nick" or return 0;
  binmode $handle, ':utf8';
  my @messages = <$handle>;
  return scalar @messages;
}

sub handle
{
  my ($nick, $mode, $error) = @_;
  $nick = cleanse_nick($nick);
  File::Path::make_path($message_dir);
  open my $handle, $mode, "$message_dir/$nick" or do
  {
    print "$error\n";
    exit;
  };
  binmode $handle, ':utf8';
  return $handle;
}

sub clear
{
  my $nick = cleanse_nick(shift);
  system("rm '$message_dir/$nick'");
}

sub notify
{
  my $nick = cleanse_nick(shift);
  my $reset = shift;

  if ($reset)
  {
    chmod 0666, "$message_dir/$nick";
    return;
  }

  # if the message file has +x set, then don't notify
  return 0 if -x "$message_dir/$nick";
  chmod 0777, "$message_dir/$nick";
  return 1;
}

1
