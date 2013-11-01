#! /usr/bin/env ruby

require 'helper'
require 'sqlhelper'

help("Supplies URLs to the user's last ttyrecs. Accepts !listgame " +
     "style selectors.")

sql_show_game_with_extras(ARGV[1], ARGV[2], ['-ttyrec'])
