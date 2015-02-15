module Formatter
  class GameText
    def self.format(res, opts)
      if opts.empty?
        print_game_n(res.qualified_index, res.game)
      else
        "#{game_number_prefix(res.qualified_index)}#{short_game_summary(res.game)}: #{optmsg(opts)}"
      end
    end

    def self.format_milestone_game(mile, game, opts)
      if !game
        short_game_summary(mile.game) + " has no matching game"
      elsif opts.empty?
        print_game_n(mile.game_key, game)
      else
        "#{short_game_summary(game)}: " + optmsg(opts)
      end
    end

  private

    def self.print_game_n(n, game)
      "\n#{n}. :#{munge_game(game)}:"
    end

    def self.optmsg(opts)
      opts.to_a.first[1].to_s
    end
  end
end
