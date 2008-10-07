#! /usr/bin/ruby

# Requests that C-SPLAT play the specified game.

require 'commands/helper'
require 'commands/sqlhelper'
require 'commands/libtv'

help("Usage: !tv <game>. Plays the game on FooTV.")

begin
  n, game, selectors =
    sql_find_game(ARGV[1], ARGV[2].split()[1 .. -1])
  raise "No games for #{selectors}." unless game
  TV.request_game_verbosely(n, game, ARGV[1])
rescue
  puts $!
  raise
end
