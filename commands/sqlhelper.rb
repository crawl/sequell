#!/usr/bin/ruby

require 'dbi'
require 'commands/helper'
require 'set'

# Important: we filter games to this set unless the user explicitly
# specifies a version.
CURRENT_VER = "0.4"

$CONSTRAIN_VERSION = false

OPERATORS = {
  '=' => '=', '!=' => '!=', '<' => '<', '>' => '>',
  '<=' => '<=', '>=' => '>=', '=~' => 'LIKE', '!~' => 'NOT LIKE',
  '~~' => 'REGEXP', '!~~' => 'NOT REGEXP'
}

CLASS_EXPANSIONS = {
  "Fi" => "Fighter",
  "Wz" => "Wizard",
  "Pr" => "Priest",
  "Th" => "Thief",
  "Gl" => "Gladiator",
  "Ne" => "Necromancer",
  "Pa" => "Paladin",
  "As" => "Assassin",
  "Be" => "Berserker",
  "Hu" => "Hunter",
  "Cj" => "Conjurer",
  "En" => "Enchanter",
  "FE" => "Fire Elementalist",
  "IE" => "Ice Elementalist",
  "Su" => "Summoner",
  "AE" => "Air Elementalist",
  "EE" => "Earth Elementalist",
  "Cr" => "Crusader",
  "DK" => "Death Knight",
  "VM" => "Venom Mage",
  "CK" => "Chaos Knight",
  "Tm" => "Transmuter",
  "He" => "Healer",
  "Re" => "Reaver",
  "St" => "Stalker",
  "Mo" => "Monk",
  "Wr" => "Warper",
  "Wn" => "Wanderer"
}

RACE_EXPANSIONS = {
  'Hu' => 'Human',
  'HE' => 'High Elf',
  'GE' => 'Grey Elf',
  'DE' => 'Deep Elf',
  'SE' => 'Sludge Elf',
  'MD' => 'Mountain Dwarf',
  'Ha' => 'Halfling',
  'HO' => 'Hill Orc',
  'Ko' => 'Kobold',
  'Mu' => 'Mummy',
  'Na' => 'Naga',
  'Gn' => 'Gnome',
  'Og' => 'Ogre',
  'Tr' => 'Troll',
  'OM' => 'Ogre-Mage',
  'Dr' => 'Draconian',
  'Ce' => 'Centaur',
  'DG' => 'Demigod',
  'Sp' => 'Spriggan',
  'Mi' => 'Minotaur',
  'DS' => 'Demonspawn',
  'Gh' => 'Ghoul',
  'Ke' => 'Kenku',
  'Mf' => 'Merfolk',
  'Vp' => 'Vampire'
}

[ CLASS_EXPANSIONS, RACE_EXPANSIONS ].each do |hash|
  hash.keys.each do |key|
    hash[key.downcase] = hash[key]
  end
end

OPEN_PAREN = '(('
CLOSE_PAREN = '))'

BOOLEAN_OR = '||'

COLUMN_ALIASES = {
  'role' => 'cls', 'class' => 'cls', 'species' => 'race',
  'ktype' => 'ktyp', 'score' => 'sc', 'turns' => 'turn',
  'time' => 'dur'
}

LOGFIELDS_DECORATED = %w/file src v cv lv scI name uidI race crace cls
  char xlI sk sklevI title ktyp killer ckiller kmod kaux ckaux place br lvlI
  ltyp hpI mhpI mmhpI damI strI intI dexI god pietyI penI wizI startD
  endD durI turnI uruneI nruneI tmsg vmsg splat/

FAKEFIELDS_DECORATED = %w/when/

LOGFIELDS_SUMMARIZABLE =
  Hash[ * (%w/v name race cls char xl sk sklev title ktyp place br ltyp killer
              god urune nrune src str int dex kaux ckiller cv ckaux crace kmod
              splat dam/.
             map { |x| [x, true] }.flatten) ]

# Skip so many leading fields when processing SELECT * responses.
# The skipped fields are: id, offset.
LOGFIELDS_SKIP = 2

# Never fetch more than 5000 rows, kthx.
ROWFETCH_MAX = 5000
DBFILE = "#{ENV['HOME']}/logfile.db"
LOGFIELDS = { }
FAKEFIELDS = { }

SORTEDOPS = OPERATORS.keys.sort { |a,b| b.length <=> a.length }
ARGSPLITTER = Regexp.new('^-?([a-z]+)\s*(' +
                        SORTEDOPS.map { |o| Regexp.quote(o) }.join("|") +
                        ')\s*(.*)$', Regexp::IGNORECASE)

# Automatically limit search to a specific server, unless explicitly
# otherwise requested.
SERVER = ENV['CRAWL_SERVER'] || 'cao'

[ [ LOGFIELDS_DECORATED, LOGFIELDS ],
  [ FAKEFIELDS_DECORATED, FAKEFIELDS ] ].each do |fdec,fdict|
  fdec.each do |lf|
    class << lf
      def name
        self.sub(/[ID]$/, '')
      end

      def fix_date(v)
        sql2logdate(v)
      end

      def value(v)
        (self =~ /I$/) ? v.to_i :
        (self =~ /D$/) ? fix_date(v) : v
      end
    end

    if lf =~ /([ID])$/
      type = $1
    else
      type = 'S'
    end
    fdict[ lf.name ] = type
  end
end

LOG2SQL = {
  'name' => 'pname',
  'char' => 'charabbrev',
  'str' => 'sstr',
  'dex' => 'sdex',
  'int' => 'sint',
  'start' => 'tstart',
  'end' => 'tend'
}

LOGFIELDS_DECORATED.each do |x|
  LOG2SQL[x.name] = x.name unless LOG2SQL[x.name]
end

$DB_HANDLE = nil
$group_field = nil

def sql2logdate(v)
  v = v.to_s
  if v =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})/
    # Note we're munging back to POSIX month (0-11) here.
    $1 + sprintf("%02d", $2.to_i - 1) + $3 + $4 + $5 + $6 + 'S'
  else
    v
  end
end

def with_group(group)
  old = $group_field
  $group_field = group
  begin
    yield
  ensure
    $group_field = old
  end
end

def sql_build_query(default_nick, args)
  summarize = args.find { |a| a =~ /^-?s(?:=.*)?$/ }
  args.delete(summarize) if summarize

  sfield = nil
  if summarize
    if summarize =~ /^-?s=([+-]?)(.*)$/
      sort = $1.empty? ? '+' : $1
      sfield = COLUMN_ALIASES[$2] || $2
      raise "Bad arg '#{summarize}' - cannot summarise by #{sfield}" unless LOGFIELDS_SUMMARIZABLE[sfield]
      sfield = sort + sfield
    else
      sfield = '+name'
    end
  end

  with_group(sfield) do
    args = _op_back_combine(args)
    nick = extract_nick(args) || default_nick
    num  = extract_num(args)
    q = build_query(nick, num, args, false)
    q.summarize = sfield if summarize
    q
  end
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
  (LOGFIELDS_SKIP ... row.size).each do |i|
    lfd = LOGFIELDS_DECORATED[i - LOGFIELDS_SKIP]
    map[lfd.name] = lfd.value(row[i])
  end
  map
end

class DBHandle
  def initialize(db)
    @db = db
  end

  def get_first_value(query, *binds)
    @db.prepare(query) do |sth|
      sth.execute(*binds)
      row = sth.fetch
      return row[0]
    end
    nil
  end

  def execute(query, *binds)
    @db.prepare(query) do |sth|
      sth.execute(*binds)
      while row = sth.fetch
        yield row
      end
    end
  end
end

def connect_sql_db
  DBHandle.new(DBI.connect('DBI:Mysql:henzell', 'henzell', ''))
end

def sql_dbh
  $DB_HANDLE ||= connect_sql_db
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
  sql_each_row_matching(q, n + 1) do |row|
    return [ lastcount ? n + 1 : count - n, row ] if num == 0
    num -= 1
  end
  nil
end

def sql_count_rows_matching(q)
  sql_dbh.get_first_value(q.select_count, *q.values).to_i
end

def sql_each_row_matching(q, limit=0)
  query = q.select_all
  if limit > 0
    query += " LIMIT #{limit}"
  end
  sql_dbh.execute(query, *q.values) do |row|
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
    @summary_sort = nil
    @raw = nil
  end

  # Is this a query aimed at a single nick?
  def single_nick?
    nf = LOG2SQL['name']
    @pred[1][1] == "#{nf} = ?" ||
      (@pred[0] == :field && @pred[1] == "#{nf} = ?")
  end

  def summarize
    @summarize
  end

  def summarize= (s)
    if s =~ /^([+-]?)(.*)/
      @summarize = $2
      @summary_sort = $1 == '-' ? '' : 'DESC'
    end
    @query = nil
  end

  def select(what, with_sorts=true)
    "SELECT #{what} FROM logrecord " + where(with_sorts)
  end

  def select_all
    "SELECT * FROM logrecord " + where
  end

  def select_count
    "SELECT COUNT(*) FROM logrecord " + where(false)
  end

  def summary_query
    count_on(@summarize, @summary_sort)
  end

  def count_on(field, sortdir)
    temp = @sort
    begin
      @sort = []
      @query = nil
      %{SELECT #{LOG2SQL[field]}, COUNT(*) AS fieldcount FROM logrecord
        #{where} GROUP BY #{LOG2SQL[field]} ORDER BY fieldcount #{sortdir}}
    ensure
      @sort = temp
    end
  end

  def query(with_sorts=true)
    build_query(with_sorts)
  end

  def values
    build_query unless @values
    @values || []
  end

  def pred_field_arr(p)
    fields = p[1 .. -1].collect do |e|
      if e[0] == :field
        e[3]
      else
        pred_fields(e)
      end
    end
  end

  def pred_fields(p)
    Set.new(pred_field_arr(p).flatten)
  end

  def version_predicate
    %{v #{OPERATORS['=~']} ?}
  end

  def build_query(with_sorts=true)
    @query, @values = collect_clauses(@pred)
    @query = "WHERE #{@query}" unless @query.empty?
    unless @sort.empty? or !with_sorts
      @query << " " unless @query.empty?
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

  def sort_by! (*fields)
    clear_sorts!
    sort = ""
    for field, direction in fields
      sort << ", " unless sort.empty?
      sort << "#{field} #{direction == :desc ? 'DESC' : ''}"
    end
    @sort << "ORDER BY #{LOG2SQL[sort]}"
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
    return [ preds[1], [ preds[2] ] ] if op == :field

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

def _clean_argstr(text)
  op_match = /#{SORTEDOPS.map { |o| Regexp.quote(o) }.join("|")}/
  popen = Regexp.quote(OPEN_PAREN)
  pclose = Regexp.quote(CLOSE_PAREN)
  text.gsub(/#{popen}(.*?)#{pclose}/) do |m|
    payload = $1.dup
    count = 0
    payload.gsub(op_match) do |pm|
      count += 1
      pm
    end
    if count == 1
      payload.strip
    else
      OPEN_PAREN + payload.strip + OPEN_PAREN
    end
  end
end

def _build_argstr(nick, cargs)
  cargs.empty? ? nick : "#{nick} (#{_clean_argstr(cargs.join(' '))})"
end

def build_query(nick, num, args, back_combine=true)
  args = _op_back_combine(args) if back_combine
  args = _op_separate(args)
  predicates, sorts, cargs = parse_query_params(nick, num, args)
  CrawlQuery.new(predicates, sorts, nick, num, _build_argstr(nick, cargs))
end

def _op_separate(args)
  cargs = []
  for arg in args do
    if arg =~ %r/#{Regexp.quote(OPEN_PAREN)}(\S+)/ then
      cargs << OPEN_PAREN
      cargs << $1
    elsif arg =~ %r/^(\S+)#{Regexp.quote(CLOSE_PAREN)}$/ then
      cargs << $1
      cargs << CLOSE_PAREN
    elsif arg =~ %r/^(\S*)\|(\S*)$/ then
      cargs << $1 unless $1.empty?
      cargs << BOOLEAN_OR
      cargs << $2 unless $2.empty?
    else
      cargs << arg
    end
  end
  cargs.length > args.length ? _op_separate(cargs) : cargs
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
    if cargs.empty? || arg =~ ARGSPLITTER ||
        [OPEN_PAREN, CLOSE_PAREN, BOOLEAN_OR].index(arg)
      cargs << arg
    else
      cargs.last << " " << arg
    end
  end
  cargs
end

def sanitize_args(args)
  _combine_args( _op_separate( _op_back_combine( args ) ) )
end

def _canonical_args(args)
  raw = args.map { |a| a.sub(ARGSPLITTER, '\1\2\3').tr('_', ' ') }
  cargs = []
  for r in raw
    if !cargs.empty? && cargs.last == OPEN_PAREN && r == CLOSE_PAREN
      cargs = cargs.slice(0, cargs.length - 1)
      next
    end
    cargs << r
  end
  cargs
end

def field_pred(v, op, fname, fexpr)
  v = proc_val(v, op)
  [ :field, "#{fexpr or fname} #{op} ?", v, fname.downcase ]
end

# Examines args for | operators at the top level and returns the
# positions of all such.
def split_or_clauses(args)
  level = 0
  i = 0
  or_positions = []
  while i < args.length
    arg = args[i]
    if arg == BOOLEAN_OR && level == 0
      or_positions << i
    end
    if arg == OPEN_PAREN
      level += 1
    elsif arg == CLOSE_PAREN
      level -= 1
      if level == -1
        or_positions << i
        return or_positions
      end
    end
    i += 1
  end
  or_positions << args.length unless or_positions.empty?
  or_positions
end

def parse_param_group(preds, sorts, args)
  # Check for top-level OR operators.
  or_pos = split_or_clauses(args)
  if not or_pos.empty?
    preds << 'OR'
    last = 0
    for i in or_pos
      slice = args.slice(last, i - last)
      subpred = []
      parse_param_group(subpred, sorts, slice)
      preds << subpred
      last = i + 1
    end
    return last
  end

  preds << 'AND'

  i = 0
  while i < args.length
    arg = args[i]

    i += 1

    return i if arg == CLOSE_PAREN
    if arg == OPEN_PAREN
      subpreds = []
      i = parse_param_group(subpreds, sorts, args[i .. -1]) + i
      preds << subpreds
      next
    end

    process_param(preds, sorts, arg)
  end
end

def process_param(preds, sorts, arg)
  raise "Malformed argument: #{arg}" unless arg =~ ARGSPLITTER
  key, op, val = $1, $2, $3

  key.downcase!
  val.downcase!
  val.tr! '_', ' '

  sort = (key == 'max' || key == 'min')

  selector = sort ? val : key
  selector = COLUMN_ALIASES[selector] || selector
  raise "Unknown selector: #{selector}" unless \
     LOGFIELDS[selector] || FAKEFIELDS[selector]
  raise "Bad sort: #{arg}" if sort && op != '='
  raise "Too many sort conditions" if sort && !sorts.empty?

  if sort
    order = key == 'max'? ' DESC' : ''
    sorts << "ORDER BY #{LOG2SQL[selector]}#{order}"
  else
    sqlop = OPERATORS[op]
    field = LOG2SQL[selector]
    if LOGFIELDS[selector] == 'I'
      if ['=~','!~','~~', '!~~'].index(op)
        raise "Can't use #{op} on numeric field #{selector}"
      end
      val = val.to_i
    end
    preds << query_field(selector, field, op, sqlop, val)
  end
end

def add_extra_predicate(p, arg, value, operator, fieldname,
                        fieldexpr, hidden=false)
  fp = field_pred(value, operator, fieldname, fieldexpr)
  p << fp
  if not hidden
    frag = "#{fieldname}#{operator}#{value}"
    arg << frag
  end
end

def pred_field_arr(p)
  fields = p[1 .. -1].collect do |e|
    if e[0] == :field
      e[3]
    else
      pred_field_arr(e)
    end
  end
end

def pred_fields(p)
  Set.new(pred_field_arr(p).flatten + [ $group_field ])
end

def augment_query(preds, canargs)
  #pfields = pred_fields(preds)
  #if $CONSTRAIN_VERSION and not pfields.include?('v')
  #  add_extra_predicate(preds, canargs, CURRENT_VER, '>=', 'v', 'v')
  #end

  #if not pfields.include?('src')
  #  add_extra_predicate(preds, canargs, SERVER, '=', 'src', 'src', true)
  #end
end

# A predicate chain can be flattened if:
# - It starts with an operator string.
# - It contains only one member.
# - All members share the same starting operator.
def flatten_predicates(pred)
  return pred unless pred.is_a? Array

  pred = [ pred[0] ] + pred[1 .. -1].map { |x| flatten_predicates(x) }

  op = pred[0]
  return pred unless op.is_a? String

  return flatten_predicates(pred[1]) if pred.length == 2

  rest = pred[1 .. -1]

  if rest.any? { |x| x[0] == op } &&
      rest.all? { |x| x[0] == op || x[0] == :field } then

    newlist = pred[1 .. -1].map { |x| x[0] == :field ? [x] : x[1 .. -1] } \
    .inject([]) { |full,p| full + p }
    return flatten_predicates([ op ] + newlist)
  end
  pred.find_all { |x| !x.is_a?(Array) || x.length > 1 }
end


def parse_query_params(nick, num, args)
  preds, sorts = [ 'AND' ], Array.new()
  preds << field_pred(nick, '=', 'name', LOG2SQL['name']) if nick != '*'

  args = _combine_args(args)

  subpreds = []
  parse_param_group(subpreds, sorts, args)
  preds << subpreds

  sorts << "ORDER BY #{LOG2SQL['end']} DESC" if sorts.empty?

  canargs = _canonical_args(args)
  augment_query(preds, canargs)
  preds = flatten_predicates(preds)
  [ preds, sorts, canargs ]
end

def query_field(selector, field, op, sqlop, val)
  if ['killer', 'ckiller'].index(selector) and \
      [ '=', '!=' ].index(op) and val !~ /^an? /i then
    clause = [ op == '=' ? 'OR' : 'AND' ]
    clause << field_pred(val, sqlop, selector, field)
    clause << field_pred("a " + val, sqlop, selector, field)
    clause << field_pred("an " + val, sqlop, selector, field)
    return clause
  end
  if selector == 'place' and !val.index(':') and
    [ '=', '!=' ].index(op) and
    ![ 'pan', 'lab', 'hell', 'blade', 'temple', 'abyss' ].index(val) then
    val = val + ':%'
    sqlop = op == '=' ? OPERATORS['=~'] : OPERATORS['!~']
  end
  if selector == 'race' || selector == 'crace'
    if val.downcase == 'dr' && (op == '=' || op == '!=')
      sqlop = op == '=' ? OPERATORS['=~'] : OPERATORS['!~']
      val = "%#{val}"
    else
      val = RACE_EXPANSIONS[val.downcase] || val
    end
  end
  if selector == 'cls'
    val = CLASS_EXPANSIONS[val.downcase] || val
  end
  if selector == 'when'
    if %w/t tourney tournament/.index(val) and [ '=', '!=' ].index(op)
      tourney = op == '='
      clause = [ tourney ? 'AND' : 'OR' ]
      lop = tourney ? '>' : '<'
      rop = tourney ? '<' : '>'
      clause << query_field('start', LOG2SQL['start'], lop, lop, '20080801')
      clause << query_field('end', LOG2SQL['end'], rop, rop, '20080901')
      return clause
    else
      raise "Bad selector #{selector} (#{selector}=t for tourney games)"
    end
  end

  field_pred(val, sqlop, selector, field)
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
      when 'killer'
        "other"
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
      val = defval if !val
      chars << [ val, row[1] ]
    end
  end

  if count == 0
    puts "No games for #{q.argstr}."
  else
    printable = chars.map do |e|
      formatter ? formatter.call(e[1], e[0]) : "#{e[1]}x#{e[0]}"
    end
    scount = count == 1 ? "One" : "#{count}"
    sgames = count == 1 ? "game" : "games"
    puts("#{scount} #{sgames} for #{q.argstr}: " +
         printable.join(separator))
  end
end

def report_grouped_games(group_by, defval, who, args, separator=', ', formatter=nil)
  with_group(group_by) do
    begin
      q = sql_build_query(who, args)
      q.summarize = group_by
      report_grouped_games_for_query(q, defval, separator, formatter)
    rescue
      puts $!
      raise
    end
  end
end

def logfile_names
  q = "SELECT file FROM logfiles;"
  logfiles = []
  sql_dbh.execute(q) do |row|
    logfiles << row[0]
  end
  logfiles
end

def paren_args(args)
  args && !args.empty? ? [ OPEN_PAREN ] + args + [ CLOSE_PAREN ] : []
end
