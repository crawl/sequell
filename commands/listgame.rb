#!/usr/bin/env ruby

require 'commands/sqlhelper'
require 'commands/helper'
require 'commands/libtv'

help("Lists a specifically-numbered game by a player with specified conditions. By default it lists the most recent game. Usage: !listgame (<player>) (<gamenumber>) (options) where options are in the form field=value, or (max|min)=field. See ??listgame for more info.")

TV.with_tv_opts(ARGV[2].split()[1 .. -1]) do |args, opts|
  sql_show_game(ARGV[1], args) do | n, g |
    if opts[:tv]
      TV.request_game_verbosely(n, g, ARGV[1])
    else
      print_game_n(n, g)
    end
  end
end
