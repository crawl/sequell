#!/usr/bin/env ruby

$:.push("src")
require 'helper'
require 'sqlhelper'

help("Gives a URL to the user's last morgue file. Accepts !listgame " +
     "style selectors.")

begin
  result = sql_find_game(ARGV[1], (ARGV[2].split)[1..-1])
rescue
  puts $!
  raise
end

if result.none?
  puts "No games for #{result.query_arguments}."
else
  report_game_log(result.index, result.game)
end
