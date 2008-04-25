#!/usr/bin/ruby
require 'commands/helper.rb'

help("Lists a specifically-numbered game by a player with specified conditions. By default it lists the most recent game. Usage: !listgame (<player>) (<gamenumber>) (option list) where option list is in the form -opt=value, or -(max|min)=value")

def parse_args
  words = ARGV[2].split(' ')[ 1..-1 ]
  [ ARGV[1], -1, '' ] if words.empty?
   
  if words[0] =~ /^[a-zA-Z]\w+$/ or words[0] == '*' or words[0] == '.'
    nick  = words.slice!(0)
    nick = '.' if nick == '*'
  end

  rest = words.join(' ') unless words.empty?

  nick ||= ARGV[1]
  rest ||= ''
  [ nick, rest ]
end

def get_sorts(preds)
  sorts = []
  preds.each do |key, op, val|
    if key == 'max' then
      # Sort high values to end
      sorts << Proc.new { |a,b| a[val] <=> b[val] }
    elsif key == 'min' then
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

nick, num, selectors = parse_args

games = nil
begin
  preds = split_selectors(selectors)
  sorts = get_sorts(preds)
  games = games_for(nick, preds)
  games.sort! { |a,b| sort_games(a, b, sorts) }
rescue
  puts $!
  raise
  exit 1
end

if games.empty?
  printf("No games for #{nick}%s.\n", selectors.empty? ? "" : " (#{preds})")
  exit
end

num = -1 if num == 0
index = num < 0 ? games.size + num : num - 1

if index < 0 or index >= games.size
  puts "Index out of range: #{num}"
  exit 1
end

print "\n#{index + 1}. :" + munge_game(games[index]) + ":"
