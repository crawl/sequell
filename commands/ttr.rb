#! /usr/bin/env ruby

$:.push('commands')
require 'helper'
require 'sqlhelper'

help("Supplies URLs to the user's last ttyrecs. Accepts !listgame " +
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
  summary = short_game_summary(result.game)
  begin
    print "#{result.index}. " + summary + ": " +
      (find_game_ttyrecs(result.game) || "Can't find ttyrec!")
  rescue
    puts "#{result.index}. " + summary + ": " + $!
    raise
  end
end
