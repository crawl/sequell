#! /usr/bin/env ruby

require 'helper.rb'
require 'sqlhelper'
require 'query/query_string'
require 'query/query_builder'
require 'sql/field_expr'
require 'sql/date'

help("Summarizes a player's public server career.")

query_string = Query::QueryString.new(ARGV[2].split()[1..-1]).with_extra
q = Query::QueryBuilder.build(ARGV[1], query_string.dup, CTX_LOG, nil, true)

full_query =
  q.select([Sql::FieldExpr.max('name'),
            Sql::FieldExpr.count_all,
            Sql::FieldExpr.min('start'),
            Sql::FieldExpr.max('end'),
            Sql::FieldExpr.max('sc'),
            Sql::FieldExpr.sum('sc'),
            Sql::FieldExpr.sum('turn'),
            Sql::FieldExpr.sum('dur')],
           false)

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

def midnight(date)
  DateTime.new(date.year, date.month, date.day)
end

if rows.empty? || rows[0][1].to_i == 0
  puts "No games for #{q.argstr}."
else
  r = rows[0]
  ngames = r[1]
  plural = ngames == 1 ? "" : "s"

  win_count = \
    sql_count_rows_matching(
       Query::QueryBuilder.build(ARGV[1], query_string + 'ktyp=winning',
                                 CTX_LOG, nil, true))

  start_date = r[2]
  end_date = r[3]

  start_time_bracket = midnight(start_date)
  end_time_bracket = midnight(end_date) + 1
  tstart = Sql::Date.display_date(start_date)
  tend = Sql::Date.display_date(end_date)

  duration = r[7]

  stats = [
    "won #{winstr(win_count, ngames)}",
    "high score #{r[4]}",
    "total score #{sqlnumber(r[5])}",
    "total turns #{sqlnumber(r[6])}"
  ]

  time_span_days = (end_time_bracket - start_time_bracket).to_f
  duration_per_day = time_span_days > 0 && duration / time_span_days
  stats << "play-time/day #{duration_str(duration_per_day)}" if duration_per_day

  stats << "total time #{duration_str(duration.to_i)}"

  puts("#{q.argstr} has played #{ngames} game#{plural}, between " +
    "#{datestr(tstart)} and #{datestr(tend)}, " + stats.join(", ") + ".")
end
