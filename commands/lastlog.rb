#!/usr/bin/env ruby

$:.push('commands')
require 'helper'
require 'sqlhelper'

help("Gives a URL to the user's last morgue file. Accepts !listgame " +
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
  report_game_log(n, game)
end
