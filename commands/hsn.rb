#!/usr/bin/ruby

require 'commands/sqlhelper'
require 'commands/helper'

help "Lists the highest-scoring game for a player."

$CONSTRAIN_VERSION = true;
begin
  n, game, selectors = sql_find_game(ARGV[1],
				     (ARGV[2].split)[1..-1] + [ "max=sc" ])
rescue
  puts $!
  raise
end

unless game
  puts "No games for #{selectors}."
else
  print "\n#{n}. :" + munge_game(game) + ":"
end
