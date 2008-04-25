#!/usr/bin/ruby

require 'commands/helper'
require 'commands/sqlhelper'

help("Gives a URL to the users last morgue file. Also accepts !listgame " +
     "style selectors.")

begin
  n, game, selectors = sql_find_game(ARGV[0], (ARGV[2].split)[1..-1])
rescue
  puts $!
  raise
end

unless game
  puts "No games for #{selectors}."
else
  print "#{n}. " + short_game_summary(game) + ": " +
    (find_game_morgue(game) || "Can't find morgue!")
end
