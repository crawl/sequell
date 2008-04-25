#!/usr/bin/ruby
require 'commands/helper.rb'

help("Shows the number of games won.\nUsage:" +
     " !won <nick> [<number of wins to skip>]")

def parse_args
  words = ARGV[2].split(' ')[ 1..-1 ]
  [ ARGV[1], 0, '' ] if words.empty?
   
  if words[0] =~ /^[a-zA-Z]\w+$/ or words[0] == '*' or words[0] == '.'
    nick  = words.slice!(0)
    nick = '.' if nick == '*'
  end

  if words[0] =~ /^[+-]?\d+$/
    num = words.slice!(0).to_i
  end

  rest = words.join(' ') unless words.empty?

  nick ||= ARGV[1]
  num  ||= 0
  rest ||= ''
  [ nick, num, rest ]
end

nick, num, selectors = parse_args

if not num or num < 0
  puts "Bad index: #{num}"
end

games = nil
begin
  preds = split_selectors(selectors)
  games = games_for(nick, preds)
rescue
  puts $!
  raise
  exit 1
end

if games.empty?
  printf("No games for #{nick}%s.\n", selectors.empty? ? "" : " (#{preds})")
  exit 0
end

wins   = []
whash  = Hash.new(0)
nwins  = 0
offset = num
first  = 0
games.each_with_index do |g, i|
  if g['ktyp'] == 'winning'
    offset -= 1
    if offset == 0
      first = i + 1
    end
    if offset < 0
      nwins += 1
      wins << g['char']
      whash[g['char']] += 1
    end
  end
end

name = games[0]['name']

def times(n)
  n == 1 ? "once"  :
  n == 2 ? "twice" :
           "#{n} times"
end

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
