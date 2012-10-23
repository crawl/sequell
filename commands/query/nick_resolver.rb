module Query
  class NickResolver
    def self.resolve_nick_expr(nick_expr, default_nick)
      if nick_is_self?(nick_expr)
        nick = default_nick
        nick = self.negate_nick(nick) if nick_negated?(nick_expr)
        return nick
      end
      nick_expr
    end

    def self.resolve_query_nick(query, default_nick)
      self.resolve_nick_expr(extract_nick(query), default_nick)
    end

    def self.extract_nick(query)
      return nil if query.empty?

      nick = nil
      args = query.args
      (0 ... args.size).each do |i|
        return nick if OPERATORS.keys.find { |x| args[i].index(x) }
        if args[i] =~ /^!?([^+0-9@-][\w_`'-]+)$/ ||
            args[i] =~ /^!?@([\w_`'-]+)$/ ||
            args[i] =~ /^!?([.])$/ ||
            args[i] =~ /^([*])$/ then
          nick = $1
          nick = "!#{nick}" if args[i] =~ /^!/

          args.slice!(i)
          query.args = args
          break
        end
      end
      nick
    end

    def nick_is_special?(nick)
      nick && nick =~ /^!?[*.]$/
    end

    def nick_is_self?(nick)
      nick.nil? || nick =~ /^!?[.]$/
    end

    def nick_negated?(nick)
      nick && nick =~ /^!/
    end

    def negate_nick(nick)
      "!#{nick}"
    end
  end
end
