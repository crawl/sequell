#! /usr/bin/env ruby

require 'helper'
require 'sqlhelper'
require 'libtv'
require 'query/query_string'
require 'query/extra_field_parser'

help("Lists milestones for the specified player. Usage: !lm (<player>) (<number>) (options) where options are in the form field=value, or (max|min)=field. See ??milestone for more info.")

ctx = CommandContext.new

TV.with_tv_opts(ctx.arguments) do |args, tvopt|
  ctx.arguments = args
  ctx.extract_options!('game', 'log', 'ttyrec')

  query = Query::QueryString.new(ctx.arguments).with_extra
  extra = Query::ExtraFieldParser.parse(query.dup, CTX_STONE)

  tv = tvopt[:tv]
  sql_show_game(ctx.default_nick, query.args, CTX_STONE) do |res|
    if ctx[:log] && res.game['verb'] == 'crash'
      puts("#{res.n}. #{short_game_summary(res.game)}: " +
           (find_milestone_crash_dump(res.game) || "Can't find crash dump."))
    elsif (ctx[:game] || ctx[:log])
      game = res.milestone_game
      if not game
        puts "#{short_game_summary(res.game)} has no matching game."
      elsif ctx[:log]
        report_game_log(nil, game)
      elsif ctx[:ttyrec]
        report_game_ttyrecs(nil, game)
      elsif tv
        TV.request_game_verbosely(res.game_key, game, ARGV[1])
      else
        CTX_STONE.with {
          print_game_n(res.game_key,
                       add_extra_fields_to_xlog_record(extra, game))
        }
      end
    elsif ctx[:ttyrec]
      # ttyrec for the milestone
      report_game_ttyrecs(res.n, res.game)
    elsif tv
      game = res.game
      if TV.seek_to_game_end?
        game['end'] = res.milestone_game && res.milestone_game['end']
      end
      TV.request_game_verbosely(res.qualified_index, res.game, ARGV[1])
    else
      print_game_result(res)
    end
  end
end
