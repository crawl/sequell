#!/usr/bin/ruby

require 'commands/sqlhelper'
require 'commands/helper'
require 'commands/libtv'

help "Lists the highest-scoring game for a player."

args, opts = extract_options(ARGV[2].split()[1 .. -1], 'tv')

begin
  n, game, selectors = \
      sql_find_game(ARGV[1], paren_args(args) + [ "max=sc" ])
rescue
  puts $!
  raise
end

if not game
  puts "No games for #{selectors}."
elsif opts[:tv]
  TV.request_game_verbosely(n, game, ARGV[1])
else
  print "\n#{n}. :" + munge_game(game) + ":"
end
