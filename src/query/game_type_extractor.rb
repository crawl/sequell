module Query
  class GameTypeExtractor
    def self.game_type(query)
      self.new(query).game_type
    end

    def initialize(query)
      @query = query
    end

    def game_type
      game = GAME_TYPE_DEFAULT
      args = @query.args
      (0 ... args.size).each do |i|
        dcarg = args[i].downcase
        game, found = game_direct_match(game, dcarg)
        game, found = game_negated_match(game, dcarg, found)
        if found then
          args.slice!(i)
          @query.args = args
          break
        end
      end
      game
    end

    def game_direct_match(game, arg, found=nil)
      return [game, found] if found
      return [arg, true] if SQL_CONFIG.games.index(arg)
      return [game, nil]
    end

    def game_negated_match(game, arg, found=nil)
      return [game, found] if found
      if arg =~ /^!/ && SQL_CONFIG.games[1..-1].index(arg[1..-1])
        return [SQL_CONFIG.default_game_type, true]
      end
      return [game, nil]
    end
  end
end
