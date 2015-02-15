#!/usr/bin/env ruby
# encoding: UTF-8

require 'sqlhelper'
require 'helper'
require 'libtv'

help("Lists games matching specified conditions, defaulting to the most recent game played by the invoker. Usage: !lg (<player>) (<gamenumber>) (options) where options are in the form field=value, or (max|min)=field. See ??listgame for more info.")

sql_show_game_with_extras(ARGV[1], ARGV[2])
