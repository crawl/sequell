#! /usr/bin/env ruby

require 'commands/sqlhelper'
require 'commands/helper'

help("Lists the players who've died most frequently in a certain place.")

args = sanitize_args((ARGV[2].split)[1 .. -1])

params = [ "*",
           "place=#{args[0]}",
           "ktyp!=quitting",
           "ktyp!=leaving",
           "ktyp!=winning" ]

args = args[1 .. -1]

report_grouped_games('name', '', '*', params + paren_args(args))
