#! /usr/bin/ruby

require 'commands/helper.rb'
require 'commands/sqlhelper.rb'

help("Summarizes a player's crawl.akrasiac.org career.")

q = sql_build_query(ARGV[1], (ARGV[2].split)[1 .. -1])

full_query = q.select("MAX(name), COUNT(*), MIN(start), MAX(end), " +
                      "MAX(sc), SUM(sc), SUM(turn), SUM(dur)")

rows = []
sql_each_row_for_query(full_query, *q.values) do |r|
  rows << r
end

def winstr(wcount, ngames)
  s = "#{wcount}"
  if wcount > 0
    s << " " << sprintf("(%.2f%%)", wcount * 100.0 / ngames.to_f)
  end
  s
end

if rows.empty?
  puts "No games for #{q.argstr}."
else
  r = rows[0]
  ngames = r[1]
  plural = ngames == 1 ? "" : "s"
  
  win_count = \
    sql_count_rows_matching(
                            sql_build_query(ARGV[1], 
                                            (ARGV[2].split)[1 .. -1] +
                                            ["ktyp=winning"]))

  puts "#{q.argstr} has played #{ngames} game#{plural}, between " +
      "#{datestr(r[2])} and #{datestr(r[3])}, won #{winstr(win_count, ngames)}, " +
      "high score #{r[4]}, total score #{r[5]}, total turns #{r[6]}, " +
      "total time #{duration_str(r[7].to_i)}."
end
