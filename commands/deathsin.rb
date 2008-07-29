#! /usr/bin/ruby

require 'commands/sqlhelper'
require 'commands/helper'

MAX_LIST = 10

help("Lists the top #{MAX_LIST} players to die in a certain place.")

args = ARGV[2].split
place = args[1]
rest = args[2 .. -1]

def death_report(count, victims)
  vlist = victims.keys.map { |k| [ k, victims[k] ] }.sort { |b, a| a[1] <=> b[1] }
  vlist = vlist[0 ... MAX_LIST]
  freq = ""
  vlist.each do |name, times|
    freq << "#{times}x #{name}(#{sprintf('%.2f%%', times * 100.0 / count)}) "
  end
  freq
end

begin
  q = build_query('*', -1, [ "place=#{place}",
                             "ktyp!=quitting",
                             "ktyp!=winning",
                             "ktyp!=leaving" ] + paren_args(rest))

  count = sql_count_rows_matching(q)
  if count > 2000
    raise "Too many matching games (#{count})."
  end

  victims = Hash.new(0)
  canonplace = nil
  canonbranch = nil
  sql_each_row_matching(q) do |row|
    map = row_to_fieldmap(row)
    victims[map['name']] += 1

    thisplace = map['place']
    canonplace = thisplace unless canonplace

    if canonplace != thisplace
      canonbranch = map['ltyp'] != 'D' ? map['ltyp'] : map['br']
    end
  end

  place = canonbranch || canonplace || place

  if count == 0
    puts "No deaths in #{place}."
  elsif count == 1
    puts "One death in #{place}. Most frequent: #{death_report(count, victims)}"
  else
    puts "#{count} deaths in #{place}. Most frequent: #{death_report(count, victims)}"
  end
rescue
  puts $!
  raise
end
