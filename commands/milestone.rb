#! /usr/bin/env ruby

$:.push('commands')
require 'helper'
require 'sqlhelper'
require 'libtv'

help("Lists milestones for the specified player. Usage: !lm (<player>) (<number>) (options) where options are in the form field=value, or (max|min)=field. See ??milestone for more info.")

ctx = CommandContext.new

TV.with_tv_opts(ctx.arguments) do |args, tvopt|
  ctx.arguments = args
  ctx.extract_options!('game', 'log', 'ttyrec')
  sargs, extra = extra_field_clause(ctx.arguments,
                                    ctx[:game] ? CTX_LOG : CTX_STONE)

  tv = tvopt[:tv]
  sql_show_game(ctx.default_nick, sargs, CTX_STONE) do |n, g|
    if ctx[:log] && g['verb'] == 'crash'
      puts("#{n}. #{short_game_summary(g)}: " +
           (find_milestone_crash_dump(g) || "Can't find crash dump."))
    elsif (ctx[:game] || ctx[:log])
      key = g['game_key']
      game = key != nil ? sql_game_by_key(key) : nil
      if not game
        puts "#{short_game_summary(g)} has no matching game."
      elsif ctx[:log]
        report_game_log(nil, game)
      elsif ctx[:ttyrec]
        report_game_ttyrecs(nil, game)
      elsif tv
        TV.request_game_verbosely(key, game, ARGV[1])
      else
        print_game_n(key, add_extra_fields_to_xlog_record(extra, game))
      end
    elsif ctx[:ttyrec]
      # ttyrec for the milestone
      report_game_ttyrecs(n, g)
    elsif tv
      TV.request_game_verbosely(n, g, ARGV[1])
    else
      print_game_n(n, add_extra_fields_to_xlog_record(extra, g))
    end
  end
end
