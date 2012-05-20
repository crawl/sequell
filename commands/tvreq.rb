#! /usr/bin/env ruby

# Requests that C-SPLAT play the specified game.

$:.push('commands')
require 'helper'
require 'sqlhelper'
require 'libtv'

help("Usage: !tv <game>. Plays the game on FooTV.")

TV.with_tv_opts(ARGV[2].split()[1 .. -1], true) do |args, opts|
  begin
    n, game, selectors = sql_find_game(ARGV[1], args)
    raise "No games for #{selectors}." unless game
    TV.request_game_verbosely(n, game, ARGV[1])
  rescue
    puts $!
    raise
  end
end
