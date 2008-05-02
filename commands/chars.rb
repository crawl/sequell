#! /usr/bin/ruby

require 'commands/sqlhelper'
require 'commands/helper'

help("Lists the frequency of all character types a player started.")

who = ARGV[0]

begin
  q = sql_build_query(who, ARGV[2].split()[1 .. -1])
  count = sql_count_rows_matching(q)
  name = q.nick
  chars = []
  if count > 0
    q.clear_sorts!
    charquery = %{SELECT char, COUNT(*) cc FROM logrecord
                  #{q.where}
                  GROUP BY char ORDER BY cc DESC}
    sql_each_row_for_query(charquery, *q.values) do |row|
      chars << [ row[0], row[1] ]
    end
  end

  if count == 0
    puts "No games for #{q.argstr}."
  else
    puts("#{count} games for #{q.argstr}: " +
         chars.map { |e| "#{e[1]}x#{e[0]}" }.join(" "))
  end
rescue
  puts $!
  raise
end
