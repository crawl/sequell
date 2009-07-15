#!/usr/bin/ruby

require 'commands/sqlhelper'
require 'commands/helper'
require 'commands/libtv'

help "Lists the highest-scoring game for a player."

TV.with_tv_opts(ARGV[2].split()[1 .. -1]) do |args, opts|
  begin
    n, game, selectors = \
      sql_find_game(ARGV[1], args + [ "max=sc" ])
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
end
