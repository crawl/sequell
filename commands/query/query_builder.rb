require 'query/query_parser'

module Query
  class QueryBuilder
    def self.build(nick, query_string, context, extra_fields=nil,
                   extract_nick_from_query=false)
      self.new(nick, query_string, context, extra_fields,
               extract_nick_from_query).build
    end

    attr_reader :nick, :num, :game

    def initialize(nick, query_string, context, extra_fields,
                   extract_nick_from_query)
      @default_nick = nick
      @nick = @default_nick
      @query_string = query_string
      @context = context
      @extra_fields = extra_fields
      @extract_nick_from_query = extract_nick_from_query
    end

    def build
      @random = @query_string.option!('-random')
      summarise = @query_string.extract! { |a|
        SummaryFieldList.summary_field?(a)
      }
      @query_string.operator_back_combine!

      if @extract_nick_from_query
        @nick = NickResolver.resolve_query_nick(@query_string, @default_nick)
      end

      @num = self.extract_num
      @game = self.extract_game_type
      GameContext.with_game(@game) do
        @context.with do
          query = self.parse_query
          query.summarise = SummaryFieldList.new(summarise) if summarise
          query.random_game = @random
          query.extra_fields = @extra_fields
          query.context = @context
          query
        end
      end
    end

    def extract_num
      return -1 if @query_string.empty?
      num = nil
      args = @query_string.args
      (0 ... args.size).each do |i|
        num = _parse_number(args[i])
        if num
          @query_string.args = args.slice(i)
          break
        end
      end
      num ? (num > 0 ? num - 1 : num) : -1
    end

    def _parse_number(arg)
      arg =~ /^[+-]?\d+$/ ? arg.to_i : nil
    end

    def extract_game_type
      game = GAME_TYPE_DEFAULT
      args = @query_string.args
      (0 ... args.size).each do |i|
        dcarg = args[i].downcase
        game, found = game_direct_match(game, dcarg)
        game, found = game_negated_match(game, dcarg, found)
        if found then
          @query_string.args = args.slice(i)
          break
        end
      end
      game
    end

    def game_direct_match(game, arg, found=nil)
      return [game, found] if found
      return [arg, true] if GAMES.index(arg)
      return [game, nil]
    end

    def game_negated_match(game, arg, found=nil)
      return [game, found] if found
      if arg =~ /^!/ && GAMES[1..-1].index(arg[1..-1])
        return [GAME_TYPE_DEFAULT, true]
      end
      return [game, nil]
    end

    def parse_query
      QueryParser.parse(@nick, @num, @query_string, @extra_fields)
    end
  end
end
