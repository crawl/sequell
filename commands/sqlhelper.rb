#!/usr/bin/ruby

require 'sqlite3'
require 'commands/helper'

OPERATORS = {
  '=' => '=', '!=' => '!=', '<' => '<', '>' => '>',
  '<=' => '<=', '>=' => '>=', '=~' => 'LIKE', '!~' => 'NOT LIKE'
}

COLUMN_ALIASES = {
  'role' => 'cls', 'class' => 'cls', 'species' => 'race'
}

LOGFIELDS_DECORATED = %w/v lv scI name uidI race cls char xlI sk
  sklevI title ktyp killer kaux place br lvlI ltyp hpI mhpI mmhpI damI
  strI intI dexI god pietyI penI wizI start end durI turnI uruneI
  nruneI tmsg vmsg/

LOGFIELDS_SUMMARIZABLE =
  Hash[ * (%w/v name race cls char xl sk title ktyp place br ltyp
              god urune nrune str int dex/.map { |x| [x, true] }.flatten) ]

# Never fetch more than 5000 rows, kthx.
ROWFETCH_MAX = 5000
DBFILE = "#{ENV['HOME']}/logfile.db"
LOGFIELDS = { }

ARGSPLITTER = Regexp.new('^-?([a-z]+)\s*(' +
                        OPERATORS.keys.map { |o| Regexp.quote(o) }.join("|") +
                        ')\s*(.*)$')


LOGFIELDS_DECORATED.each do |lf|
  class << lf
    def name
      self.sub(/I$/, '')
    end

    def value(v)
      (self =~ /I$/) ? v.to_i : v
    end
  end

  if lf =~ /I$/
    type = 'I'
  else
    type = 'S'
  end
  LOGFIELDS[ lf.name ] = type
end

$DB_HANDLE = nil

def sql_build_query(default_nick, args)
  summarize = args.find { |a| a =~ /^-?s(?:=.*)?$/ }
  args.delete(summarize) if summarize

  sfield = nil
  if summarize
    if summarize =~ /^-?s=(.*)$/
      sfield = $1
      raise "Bad arg '#{summarize}' - cannot summarise by #{sfield}" unless LOGFIELDS_SUMMARIZABLE[sfield]
    else
      sfield = 'name'
    end
  end

  args = _op_back_combine(args)
  nick = extract_nick(args) || default_nick
  num  = extract_num(args)
  q = build_query(nick, num, args)
  q.summarize = sfield if summarize
  q
end

# Given a set of arguments of the form
#       nick num etc
# runs the query and returns the matching game.
def sql_find_game(default_nick, args)
  q = sql_build_query(default_nick, args)
  n, row = sql_exec_query(q.num, q)
  [ n, row ? row_to_fieldmap(row) : nil, q.argstr ]
end

def sql_show_game(default_nick, args)
  q = sql_build_query(default_nick, args)
  if q.summarize
    report_grouped_games_for_query(q)
  else
    n, row = sql_exec_query(q.num, q)
    unless row
      puts "No games for #{q.argstr}."
    else
      print "\n#{n}. :#{munge_game(row_to_fieldmap(row))}:"
    end
  end
rescue
  puts $!
  raise
end

def row_to_fieldmap(row)
  map = { }
  (1 ... row.size).each do |i|
    lfd = LOGFIELDS_DECORATED[i - 1]
    map[lfd.name] = lfd.value(row[i])
  end
  map
end

def sql_dbh
  $DB_HANDLE ||= SQLite3::Database.new(DBFILE)
end

def index_sanity(index)
  raise "Index too large: #{index}" if index > ROWFETCH_MAX
end

def sql_exec_query(num, q, lastcount = nil)
  origindex = num

  dbh = sql_dbh

  # -1 is the natural index 0, -2 = 1, etc.
  num = -num - 1

  # If it looks like we have to fetch several rows, see if we can reduce
  # our work by reversing the sort order.
  count = lastcount || sql_count_rows_matching(q)
  return nil if count == 0

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
  sql_each_row_matching(q) do |row|
    return [ lastcount ? n + 1 : count - n, row ] if num == 0
    num -= 1
  end
  nil
end

def sql_count_rows_matching(q)
  sql_dbh.get_first_value(q.select_count, *q.values).to_i
end

def sql_each_row_matching(q)
  sql_dbh.execute(q.select_all, *q.values) do |row|
    yield row
  end
end

def sql_each_row_for_query(query_text, *params)
  sql_dbh.execute(query_text, *params) do |row|
    yield row
  end
end

class CrawlQuery
  attr_accessor :argstr, :nick, :num, :raw

  def initialize(predicates, sorts, nick, num, argstr)
    @pred = predicates
    @sort = sorts
    @nick = nick
    @num = num
    @argstr = argstr
    @values = nil
    @summarize = nil
    @raw = nil
  end

  def summarize
    @summarize
  end

  def summarize= (s)
    @summarize = s
    @query = nil
  end 

  def select_all
    "SELECT * FROM logrecord " + where
  end

  def select_count
    "SELECT COUNT(*) FROM logrecord " + where
  end

  def summary_query
    count_on(@summarize)
  end

  def count_on(field)
    temp = @sort
    begin
      @sort = []
      @query = nil
      %{SELECT #{field}, COUNT(*) AS fieldcount FROM logrecord
        #{where} GROUP BY #{field} ORDER BY fieldcount DESC}
    ensure
      @sort = temp
    end
  end

  def query
    @query || build_query
  end

  def values
    build_query unless @values
    @values
  end

  def build_query
    @query, @values = collect_clauses(@pred)
    @query = "WHERE #{where}" unless where.empty?
    unless @sort.empty?
      @query << " " unless where.empty?
      @query << @sort[0]
    end
    @query
  end

  alias where query

  def reverse
    CrawlQuery.new(@pred, reverse_sorts(@sort), @nick, @num, @argstr)
  end

  def clear_sorts!
    @sort.clear
    @query = nil
  end

  def reverse_sorts(sorts)
    sorts.map do |s|
      s =~ /\s+DESC\s*$/i ? s.sub(/\s+DESC\s*$/, '') : s + " DESC"
    end
  end

  def collect_clauses(preds)
    clauses = ''
    return clauses unless preds.size > 1

    op = preds[0]
    values = []
    preds[1 .. -1].each do |p|
      clauses << " " << op << " " unless clauses.empty?
      if p[0] == :field
        clauses << p[1]
        values << p[2]
      else
        subclause, subvalues = collect_clauses(p)
        clauses << "(#{subclause})"
        values += subvalues
      end
    end
    [ clauses, values ]
  end
end

def _build_argstr(nick, cargs)
  cargs.empty? ? nick : "#{nick} (#{cargs.join(' ')})"
end

def build_query(nick, num, args)
  predicates, sorts, cargs = parse_query_params(nick, num, args)
  CrawlQuery.new(predicates, sorts, nick, num, _build_argstr(nick, cargs))
end

def _op_back_combine(args)
  # First combination: if we have args that start with an operator,
  # combine them with the preceding arg. For instance
  # ['killer', '=', 'steam', 'dragon'] will be combined as
  # ['killer=', 'steam', 'dragon']
  cargs = []
  opstart = %r!^(#{OPERATORS.keys.map { |o| Regexp.quote(o) }.join('|')})!;
  for arg in args do
    if !cargs.empty? && arg =~ opstart
      cargs.last << arg
    else
      cargs << arg
    end
  end
  cargs
end

def _combine_args(args)
  # Second combination: Go through the arg list and check for
  # space-split args that should be combined (such as ['killer=steam',
  # 'dragon'], which should become ['killer=steam dragon']).
  cargs = []
  for arg in args do
    if cargs.empty? || arg =~ ARGSPLITTER
      cargs << arg
    else
      cargs.last << " " << arg
    end
  end
  cargs
end

def _canonical_args(args)
  args.map { |a| a.sub(ARGSPLITTER, '\1\2\3').tr('_', ' ') }
end

def parse_query_params(nick, num, args)
  preds, sorts = [ "and" ], Array.new()
  preds << [ :field, 'LOWER(name) = ?', nick.downcase ] if nick != '*'

  args = _combine_args(args)

  for arg in args do
    raise "Malformed argument: #{arg}" unless arg =~ ARGSPLITTER
    key, op, val = $1, $2, $3

    key.downcase!
    val.downcase!
    val.tr! '_', ' '

    sort = (key == 'max' || key == 'min')

    selector = sort ? val : key
    selector = COLUMN_ALIASES[selector] || selector
    raise "Unknown selector: #{selector}" unless LOGFIELDS[selector]
    raise "Bad sort: #{arg}" if sort && op != '='
    raise "Too many sort conditions" if sort && !sorts.empty?

    if sort
      order = key == 'max'? ' DESC' : ''
      sorts << "ORDER BY #{selector}#{order}"
    else
      sqlop = OPERATORS[op]
      field = selector
      if LOGFIELDS[selector] == 'I'
        raise "Can't use #{op} on numeric field #{selector}" if sqlop =~ /LIKE/
        val = val.to_i
      else
        field = "LOWER(#{field})"
      end
      preds << query_field(selector, field, op, sqlop, val)
    end
  end

  sorts << "ORDER BY offset DESC" if sorts.empty?
  [ preds, sorts, _canonical_args(args) ]
end

def query_field(selector, field, op, sqlop, val)
  if selector == 'killer' and [ '=', '!=' ].index(op) and val !~ /^a /i and
      val !~ /^an /i then
    clause = [ op == '=' ? 'OR' : 'AND' ]
    v = proc_val(val, sqlop)
    clause << [ :field, "#{field} #{sqlop} ?", v]
    clause << [ :field, "#{field} #{sqlop} ?", "a " + v ]
    clause << [ :field, "#{field} #{sqlop} ?", "an " + v ]
    return clause
  end
  if selector == 'place' and !val.index(':') and 
    [ '=', '!=' ].index(op) and
    ![ 'pan', 'lab', 'hell', 'blade', 'temple', 'abyss' ].index(val) then
    val = val + ':%'
    sqlop = op == '=' ? 'LIKE' : 'NOT LIKE'
  end
  [ :field, "#{field} #{sqlop} ?", proc_val(val, sqlop) ]
end

def proc_val(val, sqlop)
  if sqlop =~ /LIKE/
    val = val.index('*') ? val.tr('*', '%') : "%#{val}%"
  end
  val
end

def extract_nick(args)
  return nil if args.empty?

  nick = nil
  (0 ... args.size).each do |i|
    return nick if OPERATORS.keys.find { |x| args[i].index(x) }
    if args[i] =~ /^([^+0-9!-][\w_`'-]+)$/ ||
       args[i] =~ /^!([\w_`'-]+)$/ ||
       args[i] =~ /^([*.])$/ then
      nick = $1
      nick = '*' if nick == '.'
      args.slice!(i)
      break
    end
  end
  nick
end

def _parse_number(arg)
  arg =~ /^[+-]?\d+$/ ? arg.to_i : nil
end

def extract_num(args)
  return -1 if args.empty?

  num = nil
  (0 ... args.size).each do |i|
    num = _parse_number(args[i])
    if num
      args.slice!(i)
      break
    end
  end
  num ? (num > 0 ? num - 1 : num) : -1
end

def report_grouped_games_for_query(q, defval=nil, separator=', ', formatter=nil)
  count = sql_count_rows_matching(q)
  name = q.nick
  chars = []
  defval ||=
    case q.summarize
      when 'god'
        "No God"
      else
        ""
    end
  formatter ||= 
    case q.summarize
      when 'char'
        Proc.new { |n, w| "#{n}x#{w}" }
      else
        Proc.new { |n, w| "#{n}x #{w}" }
    end
  if count > 0
    sql_each_row_for_query(q.summary_query, *q.values) do |row|
      val = row[0]
      val = defval if val.empty?
      chars << [ val, row[1] ]
    end
  end

  if count == 0
    puts "No games for #{q.argstr}."
  else
    printable = chars.map do |e|
      formatter ? formatter.call(e[1], e[0]) : "#{e[1]}x#{e[0]}"
    end
    puts("#{count} games for #{q.argstr}: " +
         printable.join(separator))
  end
end

def report_grouped_games(group_by, defval, args, separator=', ', formatter=nil)
  who = args[1]
  q = sql_build_query(who, args[2].split()[1 .. -1])
  q.summarize = group_by
  report_grouped_games_for_query(q, defval, separator, formatter)
rescue
  puts $!
  raise
end
