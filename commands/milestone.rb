#! /usr/bin/ruby

require 'commands/sqlhelper'
require 'commands/helper'
require 'commands/libtv'

help("Lists milestones for the specified player. Usage: !lm (<player>) (<number>) (options) where options are in the form field=value, or (max|min)=field. See ??milestone for more info.")

args, opts = extract_options(ARGV[2].split()[1 .. -1], 'tv', 'game')

tv = opts[:tv]
sql_show_game(ARGV[1], args, CTX_STONE) do | n, g |

  if opts[:game]
    id = g['game_id']
    game = id != nil ? sql_game_by_id(id) : nil
    if not game
      puts "#{short_game_summary(g)} has no matching game."
    elsif tv
      TV.request_game_verbosely(id, game, ARGV[1])
    else
      print_game_n(g['game_id'], sql_game_by_id(id))
    end
  elsif tv
    TV.request_game_verbosely(n, g, ARGV[1])
  else
    print_game_n(n, g)
  end
end
