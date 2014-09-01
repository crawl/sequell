#! /usr/bin/env ruby

require 'helper.rb'
require 'sqlhelper'
require 'query/query_string'
require 'query/ast/funcall'
require 'sql/date'
require 'formatter/duration'

help("Summarizes a player's public server career.")

query_string = Query::QueryString.new(ARGV[2])
q = Query::ListgameQuery.parse(ARGV[1], query_string).primary_query

def field(name)
  Sql::Field.field(name)
end

Funcall = Query::AST::Funcall

full_query =
  q.select([
    Funcall.new('max', field('name')),
    Funcall.new('count_all'),
    Funcall.new('min', field('start')),
    Funcall.new('max', field('end')),
    Funcall.new('max', field('sc')),
    Funcall.new('sum', field('sc')),
    Funcall.new('sum', field('turn')),
    Funcall.new('sum', field('dur')),
  ], false)

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
       Query::ListgameQuery.parse(ARGV[1],
                                  query_string + ' ktyp=winning').primary_query)

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
  stats << "play-time/day #{Formatter::Duration.display(duration_per_day)}" if duration_per_day

  stats << "total time #{Formatter::Duration.display(duration.to_i)}"

  puts("#{q.argstr} has played #{ngames} game#{plural}, between " +
    "#{datestr(tstart)} and #{datestr(tend)}, " + stats.join(", ") + ".")
end
