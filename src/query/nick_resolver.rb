module Query
  class NickResolver
    # Given a nick that may be ".", replaces "." with a valid nick.
    def self.resolve_nick_expr(nick_expr, default_nick)
      self.new(nick_expr, default_nick).resolve
    end

    def self.resolve_query_nick(query, default_nick)
      self.resolve_nick_expr(extract_nick(query), default_nick)
    end

    def self.nick_ignores_alias?(nick)
      nick =~ /^!?@?:/
    end

    def self.extract_nick(query)
      return nil if query.empty?

      nick = nil
      args = query.args
      (0 ... args.size).each do |i|
        return nick if OPERATORS.keys.find { |x| args[i].index(x) }

        possible_nick = nick_expr(args[i])
        if possible_nick
          nick = possible_nick
          nick = "!#{nick}" if args[i] =~ /^!/

          args.slice!(i)
          query.args = args
          break
        end
      end
      nick
    end

    def self.nick_expr(arg)
      ((arg !~ /^[+-]?[0-9]*$/ && arg =~ /^!?([^+@-][\w_`'-]+)$/) ||
        arg =~ /^!?((?:@|:|@:)?[.])$/ ||
        arg =~ /^!?((?:@|:|@:)?[\w_`'.-]+)$/ ||
        arg =~ /^([*])$/) && $1
    end

    def self.nick_is_special?(nick)
      nick && nick =~ /^!?[*.]$/
    end

    def self.nick_is_self?(nick)
      nick.nil? || nick =~ /^!?(?:@|:|@:)?[.]$/
    end

    def self.nick_negated?(nick)
      nick && nick =~ /^!/
    end

    def self.negate_nick(nick)
      "!#{nick}"
    end

    attr_reader :expr, :default_nick

    def initialize(expr, default_nick)
      @expr = expr
      @default_nick = default_nick
    end

    def negated?
      NickResolver.nick_negated?(@expr)
    end

    def ignores_alias?
      NickResolver.nick_ignores_alias?(@expr)
    end

    def resolve
      if NickResolver.nick_is_self?(@expr)
        nick = self.default_nick
        nick = ":#{nick}" if ignores_alias?
        nick = NickResolver.negate_nick(nick) if negated?
        return nick
      end
      @expr
    end
  end
end
