#! /usr/bin/env ruby

require 'helper'
require 'sqlhelper'
require 'libtv'
require 'query/query_string'

help("Lists milestones for the specified player. Usage: !lm (<player>) (<number>) (options) where options are in the form field=value, or (max|min)=field. See ??milestone for more info.")

ctx = CommandContext.new

sql_show_game(ctx.default_nick, ctx.command_line) do |res|
  if res.option(:log) && res.game['verb'] == 'crash'
    puts("#{res.n}. #{short_game_summary(res.game)}: " +
      (find_milestone_crash_dump(res.game) || "Can't find crash dump."))
  elsif res.option(:game) || res.option(:log)
    game = res.milestone_game
    if not game
      puts "#{short_game_summary(res.game)} has no matching game."
    elsif res.option(:log)
      report_game_log(nil, game)
    elsif res.option(:ttyrec)
      report_game_ttyrecs(nil, game)
    elsif res.option(:tv)
      TV.request_game_verbosely(res.game_key, game, ARGV[1], res.option(:tv))
    else
      CTX_STONE.with {
        print_game_n(res.game_key, game)
      }
    end
  elsif res.option(:ttyrec)
    # ttyrec for the milestone
    report_game_ttyrecs(res.n, res.game)
  elsif res.option(:tv)
    game = res.game
    if res.option(:tv).seek_to_game_end?
      game['end'] = res.milestone_game && res.milestone_game['end']
    end
    TV.request_game_verbosely(res.qualified_index, res.game, ARGV[1],
      res.option(:tv))
  else
    print_game_result(res)
  end
end
