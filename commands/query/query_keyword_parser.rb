require 'query/query_struct'

LISTGAME_SHORTCUTS =
  [
   lambda do |arg, reproc|
     god_name = GODS.god_resolve_name(arg)
     if god_name
       return reproc.call('god', god_name)
     end
     nil
   end,
   lambda do |value, reproc|
     %w/win won quit left leav mon beam
        pois cloud star/.any? { |ktyp| value =~ /^#{ktyp}[a-z]*$/i } && 'ktyp'
   end,
   lambda do |value, reproc|
     if value =~ /^drown/i
       return reproc.call('ktyp', 'water')
     end
     nil
   end,
   lambda do |value, reproc|
     if value =~ /^\d+[.]\d+([.]\d+)*$/
       return value =~ /^\d+[.]\d+$/ ? 'cv' : 'v'
     end
     nil
   end,
   lambda do |value, reproc|
     SOURCES.index(value) ? 'src' : nil
   end,
   lambda do |value, reproc|
     context = Sql::QueryContext.context
     if context.boolean?(Sql::Field.field(value))
       return reproc.call(value.downcase, 'y')
     end
     nil
   end
  ]

module Query
  class QueryKeywordParser
    def self.parse(arg)
      self.new(arg).parse
    end

    def initialize(arg)
      @arg = arg.strip
      @atom = @arg =~ /^\S+/
    end

    def body
      @body ||= QueryStruct.new
    end

    def parse
      return self.parse_split_keywords unless @atom

      arg = @arg.dup
      negated = arg =~ /^!/
      arg.sub!(/^!/, '')
      @equal_op = negated ? '!=' : '='

      # Check if it's a nick or nick alias:
      return parse_expr('name', arg) if arg =~ /^@/
      return parse_expr('char', arg) if is_charabbrev?(arg)

      if arg =~ /^[a-z]{2}$/i then
        cls = is_class?(arg)
        sp = is_race?(arg)
        return parse_expr('cls', arg) if cls && !sp
        return parse_expr('race', arg) if sp && !cls
        if cls && sp
          raise "Ambiguous keyword: #{arg} -- may be interpreted as species or class"
        end
      end

      if Sql::QueryContext.context.value_key?(arg)
        return parse_expr('verb', arg.downcase)
      end

      if BRANCHES.branch?(arg)
        return parse_expr('place', arg)
      end

      return parse_expr('when', arg) if tourney_keyword?(arg)

      expr_parser = lambda { |field, value| parse_expr(field, value) }
      for s in LISTGAME_SHORTCUTS
        res = s.call(arg, expr_parser)
        if res
          return parse_expr(res, arg) if res.is_a?(String)
          return res
        end
      end

      raise "Malformed argument: #{arg}"
    end

    def parse_expr(field, value)
      QueryExprParser.parse("#{field}#{@equal_op}#{value}")
    end

    def parse_split_keywords
      pieces = @arg.split
      raise "Malformed argument: #{@arg}" if pieces.size <= 1
      pieces.each { |piece|
        self.body.append(QueryKeywordParser.parse(piece))
      }
      self.body
    end
  end
end
