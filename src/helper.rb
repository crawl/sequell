#!/usr/bin/env ruby

require 'set'
require 'date'
require 'command_context'
require 'yaml'
require 'fileutils'
require 'henzell/config'
require 'formatter/duration'

# Don't use more than this much memory (bytes)
MAX_MEMORY_USED = 768 * 1024 * 1024
Process.setrlimit(Process::RLIMIT_AS, MAX_MEMORY_USED)

DEBUG_HENZELL = ENV['DEBUG_HENZELL']

# Directory containing player directories that contain morgues.
DGL_MORGUE_DIR = '/var/www/crawl/rawdata'

# HTTP URL corresponding to DGL_MORGUE_DIR, with no trailing slash.
DGL_MORGUE_URL = 'http://crawl.akrasiac.org/rawdata'

DGL_TTYREC_DIR = DGL_MORGUE_DIR

DGL_TTYREC_URL = DGL_MORGUE_URL

def regex_paths(regex_path_mappings)
  regex_path_mappings.map { |regex_string, path|
    [Regexp.new(regex_string), path]
  }
end

MORGUE_DATEFORMAT = '%Y%m%d-%H%M%S'
SHORT_DATEFORMAT = '%Y%m%d%H%M%S'

NICK_ALIASES = { }
NICKMAP_FILE = Henzell::Config.file_path(
  ENV['HENZELL_TEST'] ? 'dat/nicks-test.map' : 'dat/nicks.map')

$nicks_loaded = false

module Helper
  def self.raise_private_messaging!
    if ENV['PRIVMSG'] == 'y'
      raise "This operation is forbidden in private messaging"
    end
  end

  def self.henzell_env
    Hash[ ENV.keys.find_all { |k| k =~ /^henzell_env_\w+$/i }.map { |k|
        k =~ /^henzell_env_(\w+)$/i && [$1.downcase, ENV[k]]
      } ]
  end
end

def munge_game(game)
  game.to_a.map { |x,y| "#{x}=#{y.to_s.gsub(':', '::')}" }.join(':')
end


def forbid_private_messaging!(msg=nil)
  if ENV['PRIVMSG'] == 'y'
    puts(msg) if msg
    exit 1
  end
end

def forbid_subcommand!
  if ENV['SUBCOMMAND'] == 'y'
    puts "This command may not be used as a subcommand"
    exit 1
  end
end

def forbid_proxying!
  if ENV['HENZELL_PROXIED'] == 'y'
    puts "Proxying forbidden"
  end
end

def die(msg)
  if msg =~ /%CMD%/
    arg = ARGV[2].split()[0]
    msg = msg.gsub('%CMD%', arg)
  end
  raise msg
end

def demunge_xlogline(logline) # TODO XXX XPLODE OMG
  h = Hash.new()
  if logline == ''
    return hash
  elsif logline[0] == ?: or (logline[-1] == ?: and logline[-2] != ?:)
    raise "Evil logline: #{logline}"
  end
  logline.gsub!(/::/, "\n")
  pairs = logline.split(':')
  pairs.each do |pair|
    key, value = pair.split('=', 2)
    value.gsub!(/\n/, ':')
    if $field_types[key] == 'I'
      value = value.to_i
    end
    h[key] = value
  end
  h
end

def split_selector_predicates(sel)
  pre, post = Array.new(), Array.new()
  sel.each do |key, op, val|
    raise "Unknown selector: #{key}" unless $field_types.has_key?(key)
    raise "Bad selector #{key}#{op}#{val}" if key.empty? or val.empty?
    val = val.downcase.sub(':', '::')
    val = val.to_i if $field_types[key] == 'I'
    case op
    when '='
      pre << Proc.new { |line| line.index("#{key}=#{val}") }
    when '=='
      pre << Proc.new { |line| line.index("#{key}=#{val}:") }
    when '!='
      pre << Proc.new { |line| not line.index("#{key}=#{val}") }
    when '!=='
      pre << Proc.new { |line| not line.index("#{key}=#{val}:") }
    when '<'
      post << Proc.new { |g| (g[key] || 0) < val }
    when '>'
      post << Proc.new { |g| (g[key] || 0) > val }
    when '<='
      post << Proc.new { |g| (g[key] || 0) <= val }
    when '>='
      post << Proc.new { |g| (g[key] || 0) >= val }
    when '=~'
      post << Proc.new { |g| (g[key] || '').downcase =~ /#{val.downcase}/ }
    when '!~'
      post << Proc.new { |g| (g[key] || '').downcase !~ /#{val.downcase}/ }
    else
      raise "Bad operator in #{keyval}"
    end
  end
  [ pre, post ]
end

def key_scrub(s)
  s.gsub('[^\w]', '').downcase
end

def val_scrub(s)
  s.gsub(':', '::').downcase
end

def get_predicates(nick, sel)
  arr = []
  if not nick.empty? and nick != '.' and nick != '*'
    arr << Proc.new { |line| line.index("name=#{nick}:") }
  end
  arr + sel
end

def do_grep(logfile, nick, hsel)
  matchlist = get_predicates(nick, hsel)
  raise "No selectors, will not slurp whole logfile." if matchlist.empty?
  lines = []
  File.open(logfile) do |logfile|
    count = 0
    logfile.each_line do |line|
      testline = line.downcase
      if not matchlist.find { |p| not p[testline] }
        lines << line.chomp
        count += 1
        raise "Too many matching games." if count > MAX_GREP_LINES
      end
    end
  end
  lines
end

def morgue_assemble_filename(dir, e, time, ext)
  dir + '/' + e["name"] + '/morgue-' + e["name"] + '-' + time + ext
end

def binary_search(arr, what)
  size = arr.size

  if size == 1
    return what < arr[0] ? arr[0] : nil
  end

  s = 0
  e = size

  while e - s > 1
    pivot = (s + e) / 2
    if arr[pivot] == what
      return arr[pivot]
    elsif arr[pivot] < what
      s = pivot
    else
      e = pivot
    end
  end

  e < size ? arr[e] : nil
end

def game_morgues(name)
  Dir[ DGL_MORGUE_DIR + '/' + name + '/' + 'morgue-*.txt*' ].sort
end

def morgue_timestring(e, key=nil)
  return nil if key && !e[key]

  if key
    timestamp = e[key].dup
  else
    timestamp = (e["end"] || e["time"]).dup
  end
  timestamp.sub!(/(\d{4})(\d{2})(\d{2})/) do |m|
    "#$1#{sprintf('%02d', $2.to_i + 1)}#$3-"
  end
  timestamp
end

def morgue_time(e, key=nil)
  rawts = morgue_timestring(e, key)
  rawts ? rawts.sub(/[DS]$/, "") : nil
end

def morgue_time_dst?(e, key=nil)
  morgue_timestring(e, key) =~ /D$/
end

def find_game_morgue(e)
  require 'henzell/sources'
  Henzell::Sources.instance.morgue_for(e)
end

def find_milestone_crash_dump(e)
  return nil if e['verb'] != 'crash'

  require 'henzell/sources'
  Henzell::Sources.instance.crash_dump_for(e)
end

def short_game_summary(g)
  mile = g['milestone'] ? ' (milestone)' : ''
  "#{g['name']}, XL#{g['xl']} #{g['char']}, T:#{g['turn']}#{mile}"
end

def game_number_prefix(n)
  n.nil? ? '' : n.to_s + '. '
end

def report_game_log(n, g)
  puts(game_number_prefix(n) + short_game_summary(g) + ": " +
       (find_game_morgue(g) || "Can't find morgue."))
rescue
  puts(game_number_prefix(n) + short_game_summary(g) + ": " +
       "Can't find morgue")
  raise
end

def datestr(d)
  if d =~ /^(\d{4})(\d{2})(\d{2})/
    sprintf("%s%02d%s", $1, $2.to_i + 1, $3)
  else
    d
  end
end

def ttyrec_list_string(game, ttyreclist)
  if !ttyreclist || ttyreclist.empty?
    return nil
  elsif game['milestone'] && ttyreclist.length > 1
    return ttyrec_list_string(game, [ttyreclist[-1]])
  else
    spc = ttyreclist.length == 1 ? "" : " "
    if ttyreclist.length == 1 then
      return ttyreclist[0].url
    else
      oldbase = nil
      result = ''
      for ttyrec in ttyreclist do
        baseurl = ttyrec.baseurl
        if oldbase != baseurl then
          result << ' ' unless result.empty?
          result << baseurl
          oldbase = baseurl
        end
        result << " " << ttyrec.filename
      end
      return result
    end
  end
end

def local_time(time)
  match = /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})([SD])/.match(time)
  raise "Malformed local time: #{time}" unless match

  timed = match.captures[ 0 ... -1 ].map { |t| t.to_i }
  timed[1] += 1
  dst = match.captures[-1] == 'D'

  time = Time.local(*timed)

  if dst
    time = Time.local(time.sec, time.min, time.hour, time.day,
                      time.month, time.year, time.wday, time.yday,
                      time.isdst, time.zone)
  end
  time.utc
end

def find_game_ttyrecs(game)
  require 'henzell/sources'
  ttyrecs = Henzell::Sources.instance.ttyrecs_for(game)
  ttyrec_list_string(game, ttyrecs)
end

def report_game_ttyrecs(n, game)
  puts(game_number_prefix(n) + short_game_summary(game) + ": " +
        (find_game_ttyrecs(game) || "Can't find ttyrec!"))
rescue
  raise
  puts(game_number_prefix(n) + short_game_summary(game) + ": " + $!)
  raise
end

def help(helpstring, force=false)
  if force || ARGV[3] == '1'
    helpstring = helpstring.gsub(/[\n\t]/, ' ').gsub(/ +/, ' ')
    cmd = ARGV[2].split()[0]
    if helpstring =~ /%CMD%/
      helpstring = helpstring.gsub('%CMD%', cmd)
    end
    if force && helpstring !~ /^#{Regexp.quote(cmd)}/
      helpstring = "#{cmd}: " + helpstring
    end
    puts helpstring
    exit
  end
end

def mark_nickmap_stale!
  $nicks_loaded = false
end

def load_nicks
  return if $nicks_loaded
  if File.exists?(NICKMAP_FILE)
    File.open(NICKMAP_FILE) do |f|
      f.each_line do |line|
        maps = line.split()
        # Explicitly downcase in case someone hand-edited the file.
        NICK_ALIASES[maps[0].downcase] = maps[1 .. -1].join(" ") if maps.size > 1
      end
    end
  end
  $nicks_loaded = true
end

def save_nicks
  FileUtils.mkdir_p(File.dirname(NICKMAP_FILE))
  tmp = NICKMAP_FILE + '.tmp'
  File.open(tmp, 'w') do |f|
    for k, v in NICK_ALIASES do
      f.puts "#{k} #{v}" if v
    end
  end
  File.rename(tmp, NICKMAP_FILE)
end

def nick_aliases(nick)
  load_nicks

  aliases = NICK_ALIASES[nick.downcase]
  if aliases
    arralias = aliases.split()
    return arralias if not arralias.empty?
  end
  [ nick ]
end

def nick_primary_alias(nick)
  nick_aliases(nick)[0]
end

def extract_options(args, *keys)
  keyset = Set.new(keys)
  cargs = []
  found = { }
  for arg in args
    if arg =~ /^-(\w+)(?::(.*))?$/ && keyset.include?($1)
      found[$1.to_sym] = $2 || true
    else
      cargs << arg
    end
  end
  [ cargs, found ]
end

def print_game_n(n, game)
  print "\n#{n}. :#{munge_game(game)}:"
end

def print_game_result(res)
  if res.has_format?
    puts res.format_game
  else
    print_game_n(res.qualified_index, res.game)
  end
end

def pretty_duration(durseconds)
  Formatter::Duration.display(durseconds)
end

def logger
  $logger ||= File.open('debug.log', 'w')
end

def filelog
  if DEBUG_HENZELL
    logger.puts(yield)
    logger.flush
  end
end

def debug
  if DEBUG_HENZELL
    STDERR.puts(yield)
  end
end

def pretty_date(date)
  if date =~ /^(\d{4})(\d{2})(\d{2})/
    return "$1-#{sprintf('%02d',$2.to_i + 1)}-$3"
  end
  date
end

class Object
  def as_array
    self.is_a?(Array) ? self : [self]
  end
end
