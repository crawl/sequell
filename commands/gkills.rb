#! /usr/bin/ruby

require 'commands/helper.rb'
require 'commands/sqlhelper.rb'

help("Lists the top kills for a player's ghost.")

args = (ARGV[2].split)[1 .. -1] || []

ghost = args[0] || ARGV[1]

field = \
  if ghost == '*'
    "killer=~*'s ghost"
  else
    "killer=#{ghost}'s ghost"
  end

report_grouped_games('name', '', '*', [ '*', field ] + (args[1 .. -1] || []))
