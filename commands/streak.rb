#! /usr/bin/env ruby

$:.push('commands')
require 'helper'
require 'sqlhelper'
require 'query/query_string'
require 'query/query_builder'

default_nick = ARGV[1]
args = Query::QueryString.new((ARGV[2].split)[1 .. -1])

query = Query::QueryBuilder.build(default_nick, args, CTX_LOG, nil, true)
unless query.single_nick?
  puts "Cannot check streaks for #{query.nick}"
  exit 1
end

# Streak stats:
# - All best streaks.
# - If no streaks, smallest number of games between wins.
# - All stats reset when file changes.

$between_wins  = 0
$least_between = -1
$streak_games  = 0
$streak_chars  = []
$longest_streak = 0
$longest_streak_chars = []
$games = 0
$wins = 0
$seen_win = false
$last_win = false

$name = nil

def finish_streak(reset)
  if $streak_games > 0
    if $streak_games > $longest_streak
      $longest_streak = $streak_games
      $longest_streak_chars = [ $streak_chars ]
    elsif $streak_games == $longest_streak
      $longest_streak_chars << $streak_chars
    end
  end
  if reset
    $streak_games = 0
    $streak_chars = []
  end
end

sql_each_row_matching(query.reverse) do |row|
  game = row_to_fieldmap(row)

  $name ||= game['name']
  $games += 1
  win = game['ktyp'] == 'winning'

  if win
    if $between_wins > 0 &&
        ($least_between == -1 || $between_wins < $least_between)
      $least_between = $between_wins
    end

    $wins += 1
    $streak_chars << game['char']
    $streak_games += 1
    $between_wins = 0
    $seen_win = true
  else
    finish_streak(true)
    $between_wins += 1 if $seen_win
  end

  $last_win = win
end
finish_streak(false)

$name ||= default_nick

def best_streaks
  $longest_streak_chars.map { |chars| chars.join(', ') }.join('; ')
end

def cstreak
  $streak_chars.join(', ')
end

def cstreak_suffix
  if $streak_games == 1
    puts " and has won their last game (#{cstreak})."
  elsif $streak_games > 1
    puts " and has won their last #$streak_games games (#{cstreak})."
  else
    puts "."
  end
end

def p(n, what)
  "#{n == 0 ? "no" : n == 1 ? "one" : n.to_s} #{what}#{n == 1 ? "" : "s"}"
end

begin
  raise "No games for #{query.argstr}" if $games == 0
  raise "#$name has not won in #$games games." if $wins == 0

  if $wins == 1
    if $streak_games > 0
      puts "#$name has one win (#{cstreak}) " +
        "in #$games games, and can keep going!"
    else
      puts "#$name has one win (#{best_streaks}) in #{p($games, "game")}, and has played #{p($between_wins, "game")} since."
    end
  else
    # Is there streak at all?
    if $longest_streak > 1
      # Is the longest streak the same as the current streak?
      if $longest_streak == $streak_games
        puts "#$name has #$longest_streak consecutive wins (#{cstreak}), and can keep going!"
      else
        print "#$name has #$longest_streak consecutive wins (#{best_streaks})"
        cstreak_suffix
      end
    else
      if $streak_games > 0
        puts "#$name has #{p($wins, "win")}, none consecutive, but has just won (#{cstreak}) and can keep going!"
      else
        puts "#$name has #{p($wins, "win")}, none consecutive, with a minimum of #{p($least_between, "game")} between wins."
      end
    end
  end
rescue
  puts $!
end
