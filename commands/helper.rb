#!/usr/bin/ruby

require 'set'

# fields end in S if they're strings, I if integral
$field_names = %w<vS lvS nameS uidI raceS clsS xlI skS sklevI titleS placeS brS lvlI ltypS hpI mhpI mmhpI strI intI dexI startS durI turnI scI ktypS killerS kauxS endS tmsgS vmsgS godS pietyI penI charS nruneI uruneI>
XKEYCHARS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'

$field_types = { }

FIELD_SUBST = { 'species' => 'race', 'role' => 'cls', 'class' => 'cls' }
MAX_GREP_LINES = 3000

# Directory containing player directories that contain morgues.
DGL_MORGUE_DIR = '/var/www/crawl/rawdata'

# HTTP URL corresponding to DGL_MORGUE_DIR, with no trailing slash.
DGL_MORGUE_URL = 'http://crawl.akrasiac.org/rawdata'

DGL_TTYREC_DIR = DGL_MORGUE_DIR

DGL_TTYREC_URL = DGL_MORGUE_URL

DGL_ALIEN_MORGUES = \
[
 [ %r/cdo.*-0.4$/, 'http://crawl.develz.org/morgues/0.4' ],
 [ %r/cdo.*-0.5$/, 'http://crawl.develz.org/morgues/0.5' ],
 [ %r/cdo.*-0.6$/, 'http://crawl.develz.org/morgues/0.6' ],
 [ %r/cdo.*-svn$/, 'http://crawl.develz.org/morgues/trunk' ],
 [ %r/rhf.*-0.5$/, 'http://rl.heh.fi/crawl/stuff' ],
 [ %r/rhf.*-0.6$/, 'http://rl.heh.fi/crawl-0.6/stuff' ],
 [ %r/rhf.*-trunk$/, 'http://rl.heh.fi/trunk/stuff' ],
]

# The time (approximate) that Crawl switched from local time to UTC in
# logfiles. We'll have lamentable inaccuracy near this time, but that
# can't be helped.
LOCAL_UTC_EPOCH = Time.utc(2008, 8, 7, 3, 30)

NICK_ALIASES = { }
NICKMAP_FILE = 'nicks.map'
$nicks_loaded = false

$field_names.each do |field|
  if field =~ /(\w+)(\w)/
    $field_types[$1] = $2
  end
end

def munge_game(game)
  game.to_a.map { |x,y| "#{x}=#{y.to_s.gsub(':', '::')}" }.join(':')
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

def select_games(nick, hsel)
  # No more direct grepping.
  ####games = %x{grep -i ':name=#{nick}:' /var/www/crawl/allgames.txt} .
  do_grep('/var/www/crawl/allgames.txt', nick, hsel).
          map       {|line| demunge_xlogline(line) }
end

def games_for(nick, selectors)
  # this is partly to cleanse for safe inclusion in a shell command
  # but also partly to find nicks easier
  # the removal of numbers at the end is because Crawl nicks can't end with #s
  nick = nick.downcase.gsub(/[^a-z0-9]/, '') #.sub(/\d+$/, '')

  hsel, nsel = split_selector_predicates(selectors)
  games = select_games(nick, hsel)
  nsel.empty? ? games : games.delete_if { |g| nsel.find { |p| not p[g] } }
end

def split_selectors(selectors, regex=/^-(\w+)(<=?|>=?|[!=]~|!==?|==?)(.*)/)
  sels = [ ]
  selectors.split(' ').each do |keyval|
    if keyval =~ regex
      key, op, val = $1, $2, $3.tr('_', ' ')
      key = FIELD_SUBST[key] if FIELD_SUBST.has_key?(key)
      sels << [key, op, val]
    else
      raise "Bad selector #{keyval} - must be of the form -key=val"
    end
  end
  sels
end

def parse_game_select_args(args)
  words = args[1].split(' ')[ 1..-1 ]
  return [ args[0], -1, '' ] if !words || words.empty?

  if words[0] =~ /^[a-zA-Z]\w+$/ or words[0] == '*' or words[0] == '.'
    nick  = words.slice!(0)
    nick = '*' if nick == '.'
  end

  if not words.empty? and words[0] =~ /^[+\-]?\d+$/
    num = words.slice!(0).to_i
  end

  rest = words.join(' ') unless words.empty?

  nick ||= args[0]
  num  ||= -1
  rest ||= ''
  [ nick, num, rest ]
end

def get_game_select_sorts(preds)
  sorts = []
  preds.each do |key, op, val|
    if key == 'max' then
      raise "No field named #{val}" unless $field_types[val]
      # Sort high values to end
      sorts << Proc.new { |a,b| a[val] <=> b[val] }
    elsif key == 'min' then
      raise "No field named #{val}" unless $field_types[val]
      sorts << Proc.new { |a,b| b[val] <=> a[val] }
    end
  end
  preds.delete_if { |k,o,v| k == 'max' or k == 'min' }
  sorts
end

def sort_games(a, b, sorts)
  sorts.each do |p|
    val = p[a, b]
    return val unless val == 0
  end
  0
end

def get_named_game(args)
  nick, num, selectors = parse_game_select_args(args)
  preds = split_selectors(selectors)
  sorts = get_game_select_sorts(preds)
  games = games_for(nick, preds)
  games.sort! { |a,b| sort_games(a, b, sorts) }

  if games.empty?
    raise(
          sprintf("No games for #{nick}%s.",
                  selectors.empty? ? "" : " (#{selectors})"))
  end

  num = -1 if num == 0
  index = num < 0 ? games.size + num : num - 1
  raise "Index out of range: #{num}" if index < 0 or index >= games.size

  [ index + 1, games[index] ]
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

def morgue_time(e)
  timestamp = (e["end"] || e["time"]).dup
  timestamp.sub!(/(\d{4})(\d{2})(\d{2})/) do |m|
    "#$1#{sprintf('%02d', $2.to_i + 1)}#$3-"
  end
  timestamp.sub(/[DS]$/, "")
end

def find_alien_morgue(e)
  if e['v'] < '0.4'
    raise "Can't locate remote morgues with v<0.4"
  end
  for pair in DGL_ALIEN_MORGUES
    if e['file'] =~ pair[0]
      return morgue_assemble_filename(pair[1], e, morgue_time(e), '.txt')
    end
  end
  nil
end

def find_game_morgue(e)
  return find_game_morgue_ext(e, ".txt", false) ||
    find_game_morgue_ext(e, ".txt.bz2", false) ||
    find_game_morgue_ext(e, ".txt.gz", false) ||
    find_game_morgue_ext(e, ".txt", true)
end

def find_game_morgue_ext(e, ext, full_scan)
  if e['src'] != 'cao'
    return find_alien_morgue(e)
  end

  fulltime = morgue_time(e)

  # Look for full timestamp
  morgue = morgue_assemble_filename(DGL_MORGUE_DIR, e, fulltime, ext)
  if File.exist?(morgue)
    return morgue_assemble_filename(DGL_MORGUE_URL, e, fulltime, ext)
  end

  parttime = fulltime.sub(/\d{2}$/, '')
  morgue = morgue_assemble_filename(DGL_MORGUE_DIR, e, parttime, ext)
  if File.exist?(morgue)
    return morgue_assemble_filename(DGL_MORGUE_URL, e, parttime, ext)
  end

  if full_scan
    # We're in El Suck territory. Scan the directory listing.
    morgue_list = game_morgues(e["name"])

    # morgues are sorted. The morgue date should be greater than the
    # full timestamp.

    found = binary_search(morgue_list, morgue)
    if found then
      found.sub!(/.*morgue-\w+-(.*)/, '\1')
      return morgue_assemble_filename(DGL_MORGUE_URL, e, found, '')
    end
  end

  nil
end

def crashdump_assemble_filename(urlbase, milestone)
  (urlbase + '/' + milestone["name"] +
   '/crash-' + milestone["name"] + '-' +
   morgue_time(milestone) + ".txt")
end

def find_milestone_crash_dump(e)
  return nil if e['verb'] != 'crash'

  # Check for cao crashes:
  return crashdump_assemble_filename(DGL_MORGUE_URL, e) if e['src'] == 'cao'

  # No cao? Look for alien crashes
  for pair in DGL_ALIEN_MORGUES
    if e['file'] =~ pair[0]
      return crashdump_assemble_filename(pair[1], e)
    end
  end

  nil
end

def short_game_summary(g)
  mile = g['milestone'] ? ' (milestone)' : ''
  "#{g['name']}, XL#{g['xl']} #{g['char']}, T:#{g['turn']}#{mile}"
end

def report_game_log(n, g)
  puts("#{n.nil? ? '' : n.to_s + '. '}#{short_game_summary(g)}: " +
       (find_game_morgue(g) || "Can't find morgue."))
rescue
  puts("#{n.nil? ? '' : n.to_s + '. '}#{short_game_summary(g)}: $!")
end

def datestr(d)
  if d =~ /^(\d{4})(\d{2})(\d{2})/
    sprintf("%s%02d%s", $1, $2.to_i + 1, $3)
  else
    d
  end
end

def duration_str(dur)
  sprintf "%d:%02d:%02d", dur / 3600, (dur % 3600) / 60, dur % 60
end

def find_alien_ttyrecs(game)
  raise "Can't locate remote ttyrecs"
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

# Convert the time on a logfile
def tty_time(game, which)
  time = game[which]

  match = /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/.match(time)
  # Treat time as UTC and load.
  raise "Malformed time: #{time}" unless match

  all = match.captures.map { |x| x.to_i }

  # Month is zero-based in logfile.
  all[1] += 1

  mtime = Time.utc(*all)
  if mtime < LOCAL_UTC_EPOCH
    local_time(time)
  else
    mtime
  end
end

def find_ttyrecs_between(game, s, e)
  prefix = DGL_TTYREC_DIR + "/" + game['name'] + "/"
  files = Dir[ prefix + "*.ttyrec*" ]
  bracketed = files.find_all do |rfile|
    file = rfile.slice( prefix.length .. -1 )
    mtm = /^(\d{4})-(\d{2})-(\d{2})\.(\d{2}):(\d{2}):(\d{2})\.ttyrec/.match(file)
    next unless mtm
    filetime = Time.utc(*(mtm.captures.map { |x| x.to_i }))
    filetime >= s and filetime <= e
  end
  bracketed.map { |f| f.slice( prefix.length .. -1 ) }.sort
end

def find_cao_ttyrecs(game)
  tty_start = tty_time(game, 'start')
  tty_end   = tty_time(game, 'end')

  betw = find_ttyrecs_between(game, tty_start, tty_end)

  unless betw.empty?
    base_url = DGL_TTYREC_URL + "/" + game['name'] + "/"
    spc = betw.length == 1 ? "" : " "
    "#{base_url}#{spc}#{betw.join(" ")}"
  end
end

def find_game_ttyrecs(game)
  if game['src'] != 'cao'
    find_alien_ttyrecs(game)
  else
    find_cao_ttyrecs(game)
  end
end

def help(helpstring)
  if ARGV[3] == '1'
    if helpstring =~ /%CMD%/
      cmd = ARGV[2].split()[0]
      helpstring = helpstring.gsub('%CMD%', cmd)
    end
    puts helpstring
    exit
  end
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

def pretty_duration(durseconds)
  minutes = durseconds / 60
  seconds = durseconds % 60
  hours = minutes / 60
  minutes = minutes % 60
  days = hours / 24
  hours = hours % 24

  timestr = sprintf("%02d:%02d:%02d", hours, minutes, seconds)
  if days > 0
    timestr = "#{days}, #{timestr}"
  end
  timestr
end

def pretty_date(date)
  if date =~ /^(\d{4})(\d{2})(\d{2})/
    return "$1-#{sprintf('%02d',$2.to_i + 1)}-$3"
  end
  date
end
