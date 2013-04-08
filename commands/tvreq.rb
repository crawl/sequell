#! /usr/bin/env ruby

# Requests that C-SPLAT play the specified game.

require 'helper'
require 'sqlhelper'
require 'libtv'

help("Usage: !tv <game>. Plays the game on FooTV.")

begin
  result = sql_find_game(ARGV[1], ARGV[2])
  raise "No games for #{result.query_arguments}." if result.empty?
  TV.request_game_verbosely(result.qualified_index, result.game,
                            ARGV[1], result.option(:tv))
rescue
  puts $!
  raise
end
