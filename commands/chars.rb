#! /usr/bin/ruby

require 'commands/sqlhelper'
require 'commands/helper'

help("Lists the frequency of all character types a player started.")

group_by = 'char'
defval = ''
separator = ' '
formatter = nil
if ARGV[2] =~ /^[!@](\S+)/
  if $1 =~ /god/
    group_by = 'god'
    defval = 'No God'
    formatter = Proc.new { |num, val| "#{num} x #{val}" }
    separator = ', '
  end
end

report_grouped_games(group_by, defval, ARGV[1], (ARGV[2].split)[1 .. -1], 
                     separator, formatter)
