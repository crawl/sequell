#! /usr/bin/ruby

require 'commands/sqlhelper'
require 'commands/helper'

help("Lists the frequency of all character types a player started.")

group_by = 'char'
defval = ''
if ARGV[2] =~ /^!(\S+)/
  if $1 =~ "god"
    group_by = 'god'
    deval = 'No God'
  end
end

report_grouped_games(group_by, defval, ARGV)
