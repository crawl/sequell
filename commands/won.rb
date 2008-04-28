#!/usr/bin/ruby
require 'commands/helper.rb'

help("Shows the number of games won.\nUsage:" +
     " !won <nick> [<number of wins to skip>]")

def parse_args
  words = ARGV[2].split(' ')[ 1..-1 ]
  [ ARGV[1], 0 ] if words.empty?
   
  if words[0] =~ /^[a-zA-Z!]\w+$/
    nick = words.slice!(0).sub(/^!/, '')
  end

  if words[0] =~ /^[+-]?\d+$/
    num = words.slice!(0).to_i
  end

  nick ||= ARGV[1]
  num  ||= 0
  [ nick, num ]
end

def times(n)
  n == 1 ? "once"  :
  n == 2 ? "twice" :
           "#{n} times"
end

nick, num = parse_args

if not num or num < 0
  puts "Bad index: #{num}"
  exit 1
end

games = nil
begin
  q = build_query(nick, -1, [ ])
  count = 0
  wins = []

  whash  = Hash.new(0)
  nwins  = 0
  allwins = 0
  offset = num
  first  = 0

  name = nick
  sql_each_row_matching(q) do |row|
    g = row_to_fieldmap(row)
    count += 1

    name = g['name']
    if g['ktyp'] == 'winning'
      allwins += 1
      offset -= 1
      if offset == 0
        first = count
      end
      if offset < 0
        nwins += 1
        wins << g['char']
        whash[g['char']] += 1
      end
    end
  end

  if count == 0
    printf("No games for #{nick}.\n")
  elsif num > allwins
    puts "#{name} has only #{allwins} wins."
  else
    if nwins == 0 then
      if first == 0 then
        puts "#{name} has not won in #{games.size} games."
      else
        puts "#{name} has not won in #{games.size - first} games" +
          " since their #{games[first - 1]['char']}" +
          " (win ##{num})."
      end
    else
      if num == 0 then
        wins = whash.to_a.
          sort { |a,b| a.last == b.last ? a.first <=> b.first :
          b.last <=> a.last }.
          map { |a,b| "#{b}x#{a}" }.
          join(' ')
        puts "#{name} has won #{times(nwins)} in #{games.size} games " +
          "(#{sprintf('%0.2f%%', nwins * 100.0 / games.size)}): #{wins}"
      else
        wins = wins.join(', ')
        ngames = games.size - first
        perc = sprintf('%0.2f%%', nwins * 100.0 / ngames)
        puts "#{name} has won #{times(nwins)} in #{games.size - first} " + 
          "games (#{perc}) " +
          "since their #{games[first - 1]['char']} (win ##{num}): " +
          wins
      end
    end
  end
rescue
  puts $!
  raise
  exit 1
end
