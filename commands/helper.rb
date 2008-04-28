#!/usr/bin/ruby

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

$field_names.each do |field|
  if field =~ /(\w+)(\w)/
    $field_types[$1] = $2
  end
end

def munge_game(game)
  game.to_a.map { |x,y| "#{x}=#{y.to_s.gsub(':', '::')}" }.join(':')
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
  Dir[ DGL_MORGUE_DIR + '/' + name + '/' + 'morgue-*.txt' ].sort
end

def find_game_morgue(e)
  timestamp = e["end"].dup
  timestamp.sub!(/(\d{4})(\d{2})(\d{2})/) do |m| 
    "#$1#{sprintf('%02d', $2.to_i + 1)}#$3-"
  end
  timestamp.sub!(/[DS]$/, "")

  fulltime = timestamp
  
  # Look for full timestamp
  morgue = morgue_assemble_filename(DGL_MORGUE_DIR, e, fulltime, '.txt')
  if File.exist?(morgue)
    return morgue_assemble_filename(DGL_MORGUE_URL, e, fulltime, '.txt')
  end

  parttime = fulltime.sub(/\d{2}$/, '')
  morgue = morgue_assemble_filename(DGL_MORGUE_DIR, e, parttime, '.txt')
  if File.exist?(morgue)
    return morgue_assemble_filename(DGL_MORGUE_URL, e, parttime, '.txt')
  end

  # We're in El Suck territory. Scan the directory listing.
  morgue_list = game_morgues(e["name"])
  
  # morgues are sorted. The morgue date should be greater than the
  # full timestamp.

  found = binary_search(morgue_list, morgue)
  if found then
    found.sub!(/.*morgue-\w+-(.*)/, '\1')
    return morgue_assemble_filename(DGL_MORGUE_URL, e, found, '')
  end

  nil
end

def short_game_summary(g)
  "XL#{g['xl']} #{g['char']}, T:#{g['turn']}"
end

def help(helpstring)
  if ARGV[3] == '1'
    puts helpstring
    exit
  end
end
