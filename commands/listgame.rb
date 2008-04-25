#!/usr/bin/ruby

require 'commands/sqlhelper'
require 'commands/helper'

help("Lists a specifically-numbered game by a player with specified conditions. By default it lists the most recent game. Usage: !listgame (<player>) (<gamenumber>) (option list) where option list is in the form opt=value, or (max|min)=value. See ??listgame for more info.")

begin
  n, game, selectors = sql_find_game(ARGV[1],
				     (ARGV[2].split)[1..-1])
rescue
  puts $!
  raise
end

unless game
  puts "No games for #{selectors}."
else
  print "\n#{n}. :" + munge_game(game) + ":"
end
