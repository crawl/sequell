#! /usr/bin/env ruby

$:.push('commands')

require 'helper'
require 'sqlhelper'
require 'libtv'
require 'tv/channel_manager'
require 'set'
require 'irc_auth'

FORBIDDEN_CHANNEL_NAMES = Set.new(['footv', 'bartv'])

def show_help(force_help=false)
  IrcAuth::authorized_command_help(:tvdef, "Define TV channel by !lg query: `!tvdef CHANNEL !lg * ...' to add channel, `!tvdef -rm CHANNEL' to delete, `!tvdef CHANNEL' to query.", force_help)
end

class TVChannelQuery
  def self.run(channel_name, ctx)
    TV::ChannelManager.query_channel(channel_name)
  end
end

class TVChannelDelete
  def self.run(channel_name, ctx)
    TV::ChannelManager.delete_channel(channel_name)
  end
end

class TVChannelCreate
  def self.run(channel_name, ctx)
    self.new(channel_name, ctx).run
  end

  def initialize(channel_name, ctx)
    @channel_name = channel_name
    @ctx = ctx
    @command = ctx.shift!.downcase
    assert_valid_command!(@command)
  end

  def query_context
    @command == '!lg' ? CTX_LOG : CTX_STONE
  end

  def run
    assert_valid_query!
    define_channel
  end

  def define_channel
    TV::ChannelManager.add_channel(@channel_name,
      ([@command] + @ctx.arguments).join(' '))
  end

private
  def assert_valid_command!(cmd)
    if cmd != '!lg' && cmd != '!lm'
      raise StandardError, "Command (#{cmd}) must be !lg or !lm"
    end
  end

  def assert_valid_query!
    query = parse_query
    if query.size > 1
      raise StandardError, "Cannot define TV channel with double query"
    end

    if query.primary_query.summarise?
      raise StandardError, "Cannot define TV channel with summary query"
    end

    query.with_context {
      q = query.primary_query
      n, row = sql_exec_query(q.num, q)
      if !n || n < 10
        raise StandardError, "Cannot define channel: the query must supply at least 10 results."
      end
    }
  end

  def parse_query
    TV.with_tv_opts(@ctx.arguments) do |args, tvopt|
      @tvopt = tvopt
      args, opts = extract_options(args, 'game')
      sql_parse_query('???', args, self.query_context)
    end
  end
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
    TVChannelQuery.run(channel_name, ctx)
    exit
  end

  IrcAuth.authorize!(:tvdef)
  if delete_channel
    TVChannelDelete.run(channel_name, ctx)
  else
    TVChannelCreate.run(channel_name, ctx)
  end
rescue
  puts $!
end

main
