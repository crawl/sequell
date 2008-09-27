#! /usr/bin/ruby

require 'commands/helper.rb'
require 'commands/sqlhelper.rb'

help("Lists the top kills for a player's ghost.")

args = (ARGV[2].split)[1 .. -1] || []

ghost = nick_primary_alias( extract_nick(args) || ARGV[1] )

field = \
  if ghost == '*'
    "killer=~*'*ghost"
  else
    "killer=~#{ghost}'*ghost"
  end

report_grouped_games('name', '', '*', [ '*', field ] + paren_args(args))
