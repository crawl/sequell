#! /usr/bin/env ruby

$:.push('commands')

require 'helper'
require 'libtv'
require 'tv/channel_manager'
require 'tv/command'
require 'set'
require 'irc_auth'

FORBIDDEN_CHANNEL_NAMES = Set.new(['footv', 'bartv'])

def show_help(force_help=false)
  IrcAuth::authorized_command_help(:tvdef, "Define TV channel by !lg query: `!tvdef CHANNEL !lg * ...' to add channel, `!tvdef -rm CHANNEL' to delete, `!tvdef CHANNEL' to query.", force_help)
end

def valid_channel_name?(channel)
  channel =~ /^[^\s\/\\]+$/ && !FORBIDDEN_CHANNEL_NAMES.include?(channel.downcase)
end

def main
  show_help
  ctx = CommandContext.new
  delete_channel = ctx.strip_switch!('-rm')

  channel_name = ctx.shift!
  if !channel_name || channel_name.empty?
    show_help(true)
    exit
  end

  unless valid_channel_name?(channel_name)
    raise StandardError, "Not a valid channel name: #{channel_name}"
  end

  if !delete_channel && !ctx.has_arguments?
    TV::ChannelQuery.run(channel_name, ctx)
    exit
  end

  IrcAuth.authorize!(:tvdef)
  if delete_channel
    TV::ChannelDelete.run(channel_name, ctx)
  else
    TV::ChannelCreate.run(channel_name, ctx)
  end
rescue
  puts $!
  raise
end

main
