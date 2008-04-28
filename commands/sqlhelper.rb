#!/usr/bin/ruby

require 'sqlite3'

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

# Never fetch more than 5000 rows, kthx.
ROWFETCH_MAX = 5000
DBFILE = "#{ENV['HOME']}/logfile.db"
LOGFIELDS = { }

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

# Given a set of arguments of the form
#       nick num etc
# runs the query and returns the matching game.

def sql_find_game(default_nick, args)
  nick = extract_nick(args) || default_nick
  num  = extract_num(args)
  q = build_query(nick, num, args)

  n, row = sql_exec_query(num, q)
  [ n, row ? row_to_fieldmap(row) : nil, "#{nick} (#{args.join(' ')})" ]
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
  sql_dbh.get_first_value("SELECT COUNT(*) FROM logrecord " + q.where, 
                      *q.values).to_i
end

def sql_each_row_matching(q)
  sql_dbh.execute("SELECT * FROM logrecord " + q.where, *q.values) do |row|
    yield row
  end
end

class CrawlQuery
  def initialize(predicates, sorts)
    @pred = predicates
    @sort = sorts
    @values = nil
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
    CrawlQuery.new(@pred, reverse_sorts(@sort))
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

def build_query(nick, num, args)
  predicates, sorts = parse_query_params(nick, num, args)
  CrawlQuery.new(predicates, sorts)
end

def parse_query_params(nick, num, args)
  preds, sorts = [ "and" ], Array.new()

  splitter = Regexp.new('^-?([a-z]+)\s*(' + 
                        OPERATORS.keys.map { |o| Regexp.quote(o) }.join("|") + 
                        ')\s*(.*)$')

  preds << [ :field, 'LOWER(name) = ?', nick.downcase ] if nick != '*'

  # Go through the arg list and check for space-split args that should be 
  # combined (such as ['killer=steam', 'dragon'], which should become
  # ['killer=steam dragon']).
  cargs = []
  for arg in args do
    if cargs.empty? || arg =~ splitter
      cargs << arg
    else
      cargs.last << " " << arg
    end
  end

  for arg in cargs do
    raise "Malformed argument: #{arg}" unless arg =~ splitter
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
  [ preds, sorts ]
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
    if !OPERATORS.keys.find { |x| args[i].index(x) } and
        (args[i] =~ /^([^+0-9!-][\w_`'-]+)$/ ||
         args[i] =~ /^!([\w_`'-]+)$/ ||
         args[i] =~ /^([*.])$/) then
      nick = $1
      nick = '*' if nick == '.'
      args.slice!(i)
      break
    end
  end
  nick
end

def extract_num(args)
  num = nil
  (0 ... args.size).each do |i|
    if args[i] =~ /^[+-]?\d+$/
      num = args[i].to_i
      args.slice!(i)
      break
    end
  end
  num ? (num > 0 ? num - 1 : num) : -1
end
