#!/usr/bin/env ruby

if !ENV['HENZELL_SQL_QUERIES']
  raise Exception.new("sqlhelper: HENZELL_SQL_QUERIES is not set")
end

DEBUG_HENZELL = ENV['DEBUG_HENZELL']

require 'dbi'
require 'set'
require 'yaml'

require 'helper'
require 'tourney'
require 'sql_connection'
require 'henzell_config'
require 'henzell/sources'

require 'sql/config'
require 'sql/query_result'
require 'sql/version_number'
require 'sql/crawl_query'
require 'sql/summary_reporter'
require 'sql/query_context'
require 'query/grammar'
require 'query/listgame_query'
require 'query/query_string'
require 'query/summary_graph_builder'
require 'crawl/branch_set'
require 'crawl/gods'
require 'crawl/config'
require 'string_fixup'
require 'game_context'

include Tourney
include HenzellConfig

CFG = Crawl::Config.config

# Don't use more than this much memory (bytes)
MAX_MEMORY_USED = 768 * 1024 * 1024
Process.setrlimit(Process::RLIMIT_AS, MAX_MEMORY_USED)

include Query::Grammar

PLACE_FIXUPS = StringFixup.new(CFG['place-fixups'])
BRANCHES = Crawl::BranchSet.new(CFG['branches'], PLACE_FIXUPS)
UNIQUES = Set.new(CFG['uniques'].map { |u| u.downcase })
GODS = Crawl::Gods.new(CFG['god'])

SOURCES = Henzell::Sources.instance

CLASS_EXPANSIONS =
  Hash[CFG['classes'].map { |abbr, cls| [abbr, cls.sub('*', '')] }]
RACE_EXPANSIONS =
  Hash[CFG['species'].map { |abbr, sp| [abbr, sp.sub('*', '')] }]

BOOL_FIELDS = CFG['boolean-fields']

[ CLASS_EXPANSIONS, RACE_EXPANSIONS ].each do |hash|
  hash.keys.each do |key|
    hash[key.downcase] = hash[key]
  end
end

SQL_CONFIG = Sql::Config.new(CFG)

DB_NICKS = { }

CTX_LOG =
  Sql::QueryContext.new(SQL_CONFIG, '!lg', 'logrecord', 'game', nil,
                        :alias => 'lg',
                        :fields => SQL_CONFIG.logfields,
                        :synthetic_fields => SQL_CONFIG.fakefields,
                        :default_sort => 'end',
                        :raw_time_field => 'rend')

CTX_STONE =
  Sql::QueryContext.new(SQL_CONFIG, '!lm', 'milestone', 'milestone', CTX_LOG,
                        :alias => 'lm',
                        :fields => SQL_CONFIG.milefields,
                        :synthetic_fields => SQL_CONFIG.fakefields,
                        :default_sort => 'time',
                        :value_keys => SQL_CONFIG.milestone_types,
                        :raw_time_field => 'rtime',
                        :key_field => 'verb',
                        :value_field => 'noun')

# Query context - can be either logrecord or milestone, NOT thread safe.
Sql::QueryContext.context = CTX_LOG

$DB_HANDLE = nil

# Given an expression that may be prefixed with '-' to be negated,
# returns a list with the first element true if the expression had a
# '-' pair and the second element being the rest of the expression.
# '+' is accepted as a do-nothing (not negated) prefix and is
# discarded.
def split_negated_expression(expr)
  if expr =~ /^([+-])(.*)/
    [$1 == '-', $2]
  else
    [false, expr]
  end
end

# Parse a listgame argument string into
def sql_parse_query(default_nick, query_text)
  require 'query/listgame_parser'
  Query::ListgameQuery.parse(default_nick, query_text).query_list
end

def add_extra_fields_to_xlog_record(extra, xlog_record)
  if extra && !extra.empty? && xlog_record
    context = Sql::QueryContext.context
    xlog_record['extra'] = extra.fields.map(&:to_s).join(',')
  end
  xlog_record
end

# Given a set of arguments of the form
#       nick num etc
# runs the query and returns the matching game.
def sql_find_game(default_nick, args, context=CTX_LOG)
  args = Query::QueryString.new(args).args
  query_group = sql_parse_query(default_nick, args, context)
  query_group.with_context do
    q = query_group.primary_query
    sql_exec_query(q.num, q)
  end
end

def sql_show_game(default_nick, args)
  original_args = args.dup
  query_group = sql_parse_query(default_nick, args)
  query_group.with_context do
    q = query_group.primary_query

    graph_formatter =
      if q.option(:graph)
        Query::SummaryGraphBuilder.build(query_group, q.option(:graph),
                                         original_args)
      end

    if q.summarise?
      report_grouped_games_for_query(query_group, graph_formatter)
    else
      result = sql_exec_query(q.num, q)
      if result.empty?
        type = context.entity_name + 's'
        puts "No #{type} for #{q.argstr}."
      else
        if block_given?
          yield result
        else
          print_game_result(result)
        end
      end
    end
  end
rescue
  raise if $!.is_a?(NameError)
  puts $!
  raise
end

# Given a Henzell command's command-line, looks up a game and reports it,
# also recognising -tv and -log options.
def sql_show_game_with_extras(nick, other_args_string, extra_args = [])
  combined_args = other_args_string.split() + extra_args
  command_line = ::Query::QueryString.new(combined_args)
  sql_show_game(ARGV[1], command_line) do |res|
    if res.option(:tv)
      TV.request_game_verbosely(res.qualified_index, res.game, ARGV[1],
                                res.option(:tv))
    elsif res.option(:log)
      report_game_log(res.qualified_index, res.game)
    elsif res.option(:ttyrec)
      report_game_ttyrecs(res.qualified_index, res.game)
    else
      print_game_result(res)
    end
  end
end

def sql_exec_query(num, q, lastcount = nil)
  return sql_random_row(q) if q.random_game?

  origindex = num
  dbh = sql_db_handle

  # -1 is the natural index 0, -2 = 1, etc.
  num = -num - 1

  # If it looks like we have to fetch several rows, see if we can reduce
  # our work by reversing the sort order.
  count = lastcount || sql_count_rows_matching(q)
  return Sql::QueryResult.none(q) if count == 0

  if num < 0
    num = count + num
    raise "Index out of range: #{origindex}" if num < 0
  else
    raise "Index out of range: #{origindex}" if num >= count
  end

  if !lastcount && num > count / 2
    return sql_exec_query(num - count, q.reverse, count)
  end

  n = num
  sql_each_row_matching(q, n + 1) do |row|
    index = lastcount ? n + 1 : count - n
    return Sql::QueryResult.new(index, count, row, q)
  end

  Sql::QueryResult.none(q)
end

def sql_count_rows_matching(q)
  STDERR.puts "Count: #{q.select_count} (#{q.values.inspect})" if DEBUG_HENZELL
  sql_db_handle.get_first_value(q.select_count, *q.values).to_i
end

def sql_random_row(q)
  query = q.select_id(false)
  wrapped_random_query = <<QUERY
  WITH query AS (#{query}),
       selected AS (SELECT FLOOR(RANDOM() * (SELECT COUNT(*) FROM query))::INT
                    as random_offset)
  SELECT (SELECT random_offset FROM selected) selected,
         (SELECT COUNT(*) FROM query) count,
         id
    FROM query
  OFFSET (SELECT random_offset FROM selected) LIMIT 1
QUERY
  if DEBUG_HENZELL
    STDERR.puts("Random select: #{wrapped_random_query}")
  end

  index = nil
  count = nil
  id = nil
  sql_db_handle.execute(wrapped_random_query, *q.values) do |row|
    index, count, id = row
  end
  return Sql::QueryResult.none(q) unless index
  q.with_contexts {
    return sql_game_by_id(id, index, count, q)
  }
end

def sql_each_row_matching(q, limit=0)
  query = q.select_all(true, limit=limit)
  if DEBUG_HENZELL
    STDERR.puts("SELECT query: #{query}, values: #{q.values.inspect}")
  end
  sql_db_handle.execute(query, *q.values) do |row|
    yield row
  end
end

def sql_each_row_for_query(query_text, *params)
  if DEBUG_HENZELL
    STDERR.puts("sql_each_row_for_query: #{query_text}, " +
                "params: #{params.inspect}")
  end
  sql_db_handle.execute(query_text, *params) do |row|
    yield row
  end
end

def field_pred(value, op, field)
  Sql::FieldPredicate.predicate(value, op, field)
end

def sql_game_by_id(id, index, count, original_query)
  query = Sql::CrawlQuery.new(
    Query::QueryStruct.new('AND', field_pred(id, '=', 'id')),
    nil, '*', 1, original_query.argstr)
  sql_each_row_matching(query) { |row|
    return Sql::QueryResult.new(index, count, row, original_query)
  }
  return Sql::QueryResult.none(original_query)
end

def sql_game_by_key(key)
  CTX_LOG.with do
    q =
      Sql::CrawlQuery.new(
        Query::QueryStruct.new('AND',
          field_pred(key, '=', 'game_key')),
          nil, '*', 1, "gid=#{key}")
    #puts "Query: #{q.select_all}"
    r = nil
    sql_each_row_matching(q) do |row|
      r = q.row_to_fieldmap(row)
    end
    r
  end
end

def is_charabbrev? (arg)
  arg =~ /^([a-z]{2})([a-z]{2})$/i && RACE_EXPANSIONS[$1.downcase] &&
    CLASS_EXPANSIONS[$2.downcase]
end

def is_race? (arg)
  RACE_EXPANSIONS[arg.downcase]
end

def is_class? (arg)
  CLASS_EXPANSIONS[arg.downcase]
end

def report_grouped_games_for_query(q, formatter=nil)
  reporter = Sql::SummaryReporter.new(q, formatter)
  reporter.report_summary
end

def report_grouped_games(group_by, who, args, formatter=nil)
  q = Query::QueryBuilder.build(who, Query::QueryString.new(args),
                                Sql::QueryContext.context, nil, true)
  q.summarise = Sql::SummaryFieldList.new("s=#{group_by}")
  query_group = Sql::QueryList.new
  query_group << q
  report_grouped_games_for_query(query_group, formatter)
rescue
  puts $!
  raise
end

def logfile_names
  q = "SELECT file FROM logfiles;"
  logfiles = []
  sql_db_handle.execute(q) do |row|
    logfiles << row[0]
  end
  logfiles
end

def paren_args(args)
  args && !args.empty? ? [ OPEN_PAREN ] + args + [ CLOSE_PAREN ] : []
end
