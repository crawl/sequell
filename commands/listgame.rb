#!/usr/bin/ruby

require 'commands/sqlhelper'
require 'commands/helper'

help("Lists a specifically-numbered game by a player with specified conditions. By default it lists the most recent game. Usage: !listgame (<player>) (<gamenumber>) (options) where options are in the form field=value, or (max|min)=field. See ??listgame for more info.")

sql_show_game(ARGV[1], ARGV[2].split()[1 .. -1])
