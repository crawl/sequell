#! /usr/bin/ruby

require 'commands/sqlhelper'
require 'commands/helper'

help("Lists the frequency of all character types a player started.")

who = ARGV[0]

begin
  chars = Hash.new(0)
  q = build_query( who, -1, [ ] )
  count = 0
  name = who
  sql_each_row_matching(q) do |rgame|
    game = row_to_fieldmap(rgame)
    chars[game['char']] += 1
    name = game['name']
    count += 1
  end

  sorted =
    chars.keys.map { |k| [k, chars[k]] }.sort { |a,b| b[1] <=> a[1] }

  if sorted.empty?
    puts "No games for #{name}."
  else
    puts("#{name} has played #{count} games: " +
         sorted.map { |e| "#{e[1]}x#{e[0]}" }.join(" "))
  end
rescue
  puts $!
  raise
end
