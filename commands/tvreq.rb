#! /usr/bin/env ruby

# Requests that C-SPLAT play the specified game.

require 'helper'
require 'sqlhelper'
require 'libtv'

help("Usage: !tv <game>. Plays the game on FooTV.")

TV.with_tv_opts(ARGV[2].split()[1 .. -1], true) do |args, opts|
  begin
    result = sql_find_game(ARGV[1], args)
    raise "No games for #{result.query_arguments}." if result.empty?
    TV.request_game_verbosely(result.qualified_index, result.game, ARGV[1])
  rescue
    puts $!
    raise
  end
end
