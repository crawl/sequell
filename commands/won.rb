#!/usr/bin/env ruby

require 'helper'
require 'sqlhelper'
require 'query/query_string'
require 'query/game_type_extractor'
require 'query/query_builder'
require 'query/nick_resolver'

help("Shows the number of games won. Usage:" +
     " !won <nick> [<number of wins to skip>]")

def parse_args
  words = ARGV[2].split(' ')[ 1..-1 ]
  return [ ARGV[1], 0, [] ] if !words || words.empty?

  if Query::NickResolver.nick_expr(words[0])
    nick = words[0].sub(/^@/, '')
  end

  num = 0
  words.size.times do |i|
    if words[i] =~ /^[+-]?\d+$/
      num = words.slice!(i).to_i
      break
    end
  end

  nick = nil if nick == '.'

  nick ||= ARGV[1]
  [ nick, num, words ]
end

def times(n)
  n == 1 ? "once"  :
  n == 2 ? "twice" :
           "#{n} times"
end

nick, num, trail_select = parse_args
query = Query::QueryString.new(trail_select)

if not num or num < 0
  puts "Bad index: #{num}"
  exit 1
end

games = nil
begin
  desc = nick
  if num == 0
    winning_query = query + 'ktyp=winning'
    game_query = query.dup
    q = Query::QueryBuilder.build(ARGV[1], winning_query,
                                  CTX_LOG, nil, true).reverse
    game_count_query =
      Query::QueryBuilder.build(ARGV[1], game_query, CTX_LOG, nil, true)

    count = sql_count_rows_matching(game_count_query)
    desc = game_count_query.argstr
  else
    if nick == '*'
      puts "Cannot combine * with win-skip count."
      exit 0
    end
    q = Query::QueryBuilder.build(ARGV[1], query, CTX_LOG, nil, true).reverse
    desc = q.argstr
    count = 0
  end
  wins = []

  whash  = Hash.new(0)
  nwins  = 0
  allwins = 0
  offset = num
  first  = 0
  lastwin = ''
  nfinalwin = 0
  finalwin = ''

  name = nick
  sql_each_row_matching(q) do |row|
    g = q.row_to_fieldmap(row)
    count += 1 if num != 0

    name = g['name'] unless name == '*'
    if g['ktyp'] == 'winning'
      allwins += 1
      offset -= 1
      nfinalwin = count
      finalwin = g['char']
      if offset == 0
        first = count
	lastwin = g['char']
      end
      if offset < 0
        nwins += 1
        wins << g['char']
        whash[g['char']] += 1
      end
    end
  end

  if count == 0
    printf("No games for #{desc}.\n")
  else
    if nwins == 0 then
      if (num < allwins || allwins == 0) && first == 0 then
        puts "#{desc} has not won in #{count} games."
      else
        puts "#{desc} has not won in #{count - nfinalwin} games" +
          " since their #{finalwin}" +
          " (win ##{allwins})."
      end
    else
      if num == 0 then
        wins = whash.to_a.
          sort { |a,b| a.last == b.last ? a.first <=> b.first :
          b.last <=> a.last }.
          map { |a,b| "#{b}x#{a}" }.
          join(' ')
        puts "#{desc} has won #{times(nwins)} in #{count} games " +
          "(#{sprintf('%0.2f%%', nwins * 100.0 / count)}): #{wins}"
      else
        wins = wins.join(', ')
        ngames = count - first
        perc = sprintf('%0.2f%%', nwins * 100.0 / ngames)
        puts "#{desc} has won #{times(nwins)} in #{count - first} " +
          "games (#{perc}) " +
          "since their #{lastwin} (win ##{num}): " +
          wins
      end
    end
  end
rescue
  puts $!
  raise
  exit 1
end
