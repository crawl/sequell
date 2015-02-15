#! /usr/bin/env ruby

require 'helper'
require 'sqlhelper'
require 'libtv'
require 'query/query_string'

help("Lists milestones for the specified player. Usage: !lm (<player>) (<number>) (options) where options are in the form field=value, or (max|min)=field. See ??milestone for more info.")

ctx = CommandContext.new
sql_show_game_with_extras(ctx.default_nick, ctx.command_line)
