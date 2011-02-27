#! /usr/bin/env ruby

require 'commands/helper.rb'
require 'commands/sqlhelper.rb'

help("Summarizes a player's crawl.akrasiac.org career.")

q = sql_build_query(ARGV[1], (ARGV[2].split)[1 .. -1])

full_query = \
q.select("MAX(#{LOG2SQL['name']}), COUNT(*), MIN(#{LOG2SQL['start']}), " +
         "MAX(#{LOG2SQL['end']}), " +
         "MAX(sc), SUM(sc), SUM(turn), SUM(dur)", false)

rows = []
sql_each_row_for_query(full_query, *q.values) do |r|
  rows << r
end

def winstr(wcount, ngames)
  s = "#{wcount}"
  if wcount > 0
    s << " " << sprintf("(%.1f%%)", wcount * 100.0 / ngames.to_f)
  end
  s
end

def sqlnumber(num)
  sprintf("%.0f", num)
end

if rows.empty? || rows[0][1].to_i == 0
  puts "No games for #{q.argstr}."
else
  r = rows[0]
  ngames = r[1]
  plural = ngames == 1 ? "" : "s"

  win_count = \
    sql_count_rows_matching(
       sql_build_query(ARGV[1],
                       paren_args((ARGV[2].split)[1 .. -1]) +
                       ["ktyp=winning"]))

  tstart = sql2logdate(r[2])
  tend = sql2logdate(r[3])
  puts "#{q.argstr} has played #{ngames} game#{plural}, between " +
      "#{datestr(tstart)} and #{datestr(tend)}, won #{winstr(win_count, ngames)}, " +
      "high score #{r[4]}, total score #{sqlnumber(r[5])}, total turns #{sqlnumber(r[6])}, " +
      "total time #{duration_str(r[7].to_i)}."
end
