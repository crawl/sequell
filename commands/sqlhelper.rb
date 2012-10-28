#!/usr/bin/env ruby

if !ENV['HENZELL_SQL_QUERIES']
  raise Exception.new("sqlhelper: HENZELL_SQL_QUERIES is not set")
end

LG_CONFIG_FILE = 'commands/crawl-data.yml'
LG_SERVERS_FILE = 'servers.yml'

require 'dbi'
require 'set'
require 'yaml'

require 'helper'
require 'tourney'
require 'commands/sql_connection'
require 'commands/henzell_config'

require 'sql/config'
require 'sql/field_predicate'
require 'sql/query_result'
require 'sql/version_number'
require 'sql/crawl_query'
require 'sql/summary_reporter'
require 'sql/query_context'
require 'query/lg_query'
require 'query/query_struct'
require 'crawl/branch_set'
require 'crawl/gods'

include Tourney
include HenzellConfig

CFG = YAML.load_file(LG_CONFIG_FILE)
LG_SERVER_CFG = YAML.load_file(LG_SERVERS_FILE)

# Don't use more than this much memory (bytes)
MAX_MEMORY_USED = 768 * 1024 * 1024
Process.setrlimit(Process::RLIMIT_AS, MAX_MEMORY_USED)

OPERATORS = {
  '==' => '=', '!==' => '!=',
  '=' => '=', '!=' => '!=', '<' => '<', '>' => '>',
  '<=' => '<=', '>=' => '>=', '=~' => 'ILIKE', '!~' => 'NOT ILIKE',
  '~~' => '~*', '!~~' => '!~*'
}

OPERATOR_NEGATION = {
  '=='  => '!==',
  '='   => '!=',
  '<'   => '>=',
  '>'   => '<=',
  '=~'  => '!~',
  '~~'  => '!~~'
}
OPERATOR_NEGATION.merge!(OPERATOR_NEGATION.invert)

FILTER_OPS = {
  '<'   => Proc.new { |a, b| a.to_f < b },
  '<='  => Proc.new { |a, b| a.to_f <= b },
  '>'   => Proc.new { |a, b| a.to_f > b },
  '>='  => Proc.new { |a, b| a.to_f >= b },
  '='   => Proc.new { |a, b| a.to_f == b },
  '!='  => Proc.new { |a, b| a.to_f != b }
}

FILTER_OPS_ORDERED = FILTER_OPS.keys.sort { |a,b| b.length <=> a.length }

FILTER_PATTERN =
  Regexp.new('^((?:(?:den|num|%)[.])?\S+?)(' +
             FILTER_OPS_ORDERED.map { |o| Regexp.quote(o) }.join('|') +
             ')(\S+)$')

BRANCHES = Crawl::BranchSet.new(CFG['branches'])
GODS = Crawl::Gods.new(CFG['god'])

SOURCES = LG_SERVER_CFG['sources'].keys.sort

CLASS_EXPANSIONS = CFG['classes']
RACE_EXPANSIONS = CFG['species']

BOOL_FIELDS = CFG['boolean-fields']

[ CLASS_EXPANSIONS, RACE_EXPANSIONS ].each do |hash|
  hash.keys.each do |key|
    hash[key.downcase] = hash[key]
  end
end

OPEN_PAREN = '(('
CLOSE_PAREN = '))'

BOOLEAN_OR = '||'
BOOLEAN_OR_Q = Regexp.quote(BOOLEAN_OR)

# Never fetch more than 5000 rows, kthx.
ROWFETCH_MAX = 5000

SQL_CONFIG = Sql::Config.new(CFG)

SORTEDOPS = OPERATORS.keys.sort { |a,b| b.length <=> a.length }
OPMATCH = Regexp.new(SORTEDOPS.map { |o| Regexp.quote(o) }.join('|'))
ARGSPLITTER = Regexp.new('^-?([a-z.:_]+)\s*(' +
                         SORTEDOPS.map { |o| Regexp.quote(o) }.join("|") +
                         ')\s*(.*)$', Regexp::IGNORECASE)

DB_NICKS = { }

module GameContext
  @@game = GAME_TYPE_DEFAULT

  def self.with_game(game)
    begin
      old_game = @@game
      @@game = game
      yield
    ensure
      @@game = old_game
    end
  end

  def self.game
    @@game
  end
end

CTX_LOG =
  Sql::QueryContext.new(SQL_CONFIG, 'logrecord', 'game', nil,
                        :alias => 'lg',
                        :fields => SQL_CONFIG.logfields,
                        :synthetic_fields => SQL_CONFIG.fakefields,
                        :default_sort => 'end',
                        :raw_time_field => 'rend')

CTX_STONE =
  Sql::QueryContext.new(SQL_CONFIG, 'milestone', 'milestone', CTX_LOG,
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
def sql_parse_query(default_nick, args, context=CTX_LOG)
  query = Query::LgQuery.new(default_nick, args, context)
  query.query_list
end

def add_extra_fields_to_xlog_record(extra_fields, xlog_record)
  if extra_fields && !extra_fields.empty? && xlog_record
    xlog_record['extra'] = extra_fields.fields.join(",")
  end
  xlog_record
end

# Given a set of arguments of the form
#       nick num etc
# runs the query and returns the matching game.
def sql_find_game(default_nick, args, context=CTX_LOG)
  query_group = sql_parse_query(default_nick, args, context)
  query_group.with_context do
    q = query_group.primary_query
    sql_exec_query(q.num, q)
  end
end

def sql_show_game(default_nick, args, context=CTX_LOG)
  query_group = sql_parse_query(default_nick, args, context)
  query_group.with_context do
    q = query_group.primary_query
    if q.summarise?
      report_grouped_games_for_query(query_group)
    else
      result = sql_exec_query(q.num, q)
      type = context.entity_name + 's'
      if result.empty?
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
  puts $!
  raise
end

# Given a Henzell command's command-line, looks up a game and reports it,
# also recognising -tv and -log options.
def sql_show_game_with_extras(nick, other_args_string, extra_args = [])
  TV.with_tv_opts(other_args_string.split()[1 .. -1]) do |args, opts|
    args, logopts = extract_options(args, 'log', 'ttyrec')
    sql_show_game(ARGV[1], args + extra_args) do |res|
      if opts[:tv]
        TV.request_game_verbosely(res.qualified_index, res.game, ARGV[1])
      elsif logopts[:log]
        report_game_log(res.n, res.game)
      elsif logopts[:ttyrec]
        report_game_ttyrecs(res.n, res.game)
      else
        print_game_result(res)
      end
    end
  end
end

def row_to_fieldmap(row)
  map = { }
  columns = Sql::QueryContext.context.db_columns
  (0 ... row.size).each do |i|
    lfd = columns[i]
    map[lfd.name] = lfd.value(row[i])
  end
  map
end

def index_sanity(index)
  #raise "Index too large: #{index}" if index > ROWFETCH_MAX
end

def sql_exec_query(num, q, lastcount = nil)
  origindex = num

  dbh = sql_db_handle

  # -1 is the natural index 0, -2 = 1, etc.
  num = -num - 1

  # If it looks like we have to fetch several rows, see if we can reduce
  # our work by reversing the sort order.
  count = lastcount || sql_count_rows_matching(q)
  return Sql::QueryResult.none(q) if count == 0

  if q.random_game?
    num = rand(count)
    q.random_game = false
  end

  if num < 0
    num = count + num
    raise "Index out of range: #{origindex}" if num < 0
  else
    raise "Index out of range: #{origindex}" if num >= count
  end

  if !lastcount && num > count / 2
    return sql_exec_query(num - count, q.reverse, count)
  end

  index_sanity(num)

  n = num
  sql_each_row_matching(q, n + 1) do |row|
    index = lastcount ? n + 1 : count - n
    return Sql::QueryResult.new(index, count, row, q)
  end

  Sql::QueryResult.none(q)
end

def sql_count_rows_matching(q)
  STDERR.puts "Count Query: #{q.select_count} (#{q.values.join(', ')})"
  sql_db_handle.get_first_value(q.select_count, *q.values).to_i
end

def sql_each_row_matching(q, limit=0)
  query = q.select_all
  if limit > 0
    if limit > 1
      query += " LIMIT 1 OFFSET #{limit - 1}"
    else
      query += " LIMIT #{limit}"
    end
  end
  STDERR.puts("SELECT query: #{query}")
  sql_db_handle.execute(query, *q.values) do |row|
    yield row
  end
end

def sql_each_row_for_query(query_text, *params)
  STDERR.puts "sql_each_row_for_query: #{query_text}"
  sql_db_handle.execute(query_text, *params) do |row|
    yield row
  end
end

def field_pred(value, op, field)
  Sql::FieldPredicate.predicate(v, op, field)
end

def sql_game_by_key(key)
  CTX_LOG.with do
    q =
      Sql::CrawlQuery.new(
        Query::QueryStruct.new('AND',
          field_pred(key, '=', 'game_key')),
          [ ], nil, '*', 1, "gid=#{key}")
    #puts "Query: #{q.select_all}"
    r = nil
    sql_each_row_matching(q) do |row|
      r = row_to_fieldmap(row)
    end
    r
  end
end

def is_charabbrev? (arg)
  arg =~ /^([a-z]{2})([a-z]{2})/i && RACE_EXPANSIONS[$1.downcase] &&
    CLASS_EXPANSIONS[$2.downcase]
end

def is_race? (arg)
  RACE_EXPANSIONS[arg.downcase]
end

def is_class? (arg)
  CLASS_EXPANSIONS[arg.downcase]
end

def report_grouped_games_for_query(q, defval=nil, separator=', ', formatter=nil)
  Sql::SummaryReporter.new(q, defval, separator, formatter).report_summary
end

def report_grouped_games(group_by, defval, who, args,
                         separator=', ', formatter=nil)
  q = sql_build_query(who, args)
  q.summarise = SummaryFieldList.new("s=#{group_by}")
  query_group = QueryList.new
  query_group << q
  report_grouped_games_for_query(query_group, defval, separator, formatter)
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
