#!/usr/bin/env ruby

require 'commands/sqlhelper'
require 'commands/helper'
require 'commands/libtv'

help("Lists games matching specified conditions. By default it lists the most recent game played by the invoker. Usage: !listgame (<player>) (<gamenumber>) (options) where options are in the form field=value, or (max|min)=field. See ??listgame or http://is.gd/sequell_lg for more info.")

sql_show_game_with_extras(ARGV[1], ARGV[2])
