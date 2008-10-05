#! /usr/bin/ruby

require 'commands/sqlhelper'
require 'commands/helper'

help("Lists milestones for the specified player. Usage: !lm (<player>) (<number>) (options) where options are in the form field=value, or (max|min)=field. See ??milestone for more info.")

sql_show_game(ARGV[1], ARGV[2].split()[1 .. -1], CTX_STONE)
