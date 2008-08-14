#! /usr/bin/ruby

require 'commands/helper'
require 'commands/sqlhelper'

help("Supplies URLs to the user's last ttyrecs. Accepts !listgame " +
     "style selectors.")

begin
  n, game, selectors = sql_find_game(ARGV[1], (ARGV[2].split)[1..-1])
rescue
  puts $!
  raise
end

unless game
  puts "No games for #{selectors}."
else
  summary = short_game_summary(game)
  begin
    print "#{n}. " + summary + ": " +
      (find_game_ttyrecs(game) || "Can't find ttyrec!")
  rescue
    print "#{n}. " + summary + ": " + $!
    raise
  end
end
