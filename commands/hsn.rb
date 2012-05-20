#!/usr/bin/env ruby

$:.push('commands')
require 'helper'
require 'sqlhelper'
require 'libtv'

help "Lists the highest-scoring game for a player."

sql_show_game_with_extras(ARGV[1], ARGV[2], [ "max=sc" ])
