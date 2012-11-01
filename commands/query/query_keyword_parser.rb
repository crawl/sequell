require 'query/query_struct'
require 'query/compound_keyword_parser'
require 'query/keyword_matcher'
require 'query/keyword_defs'
require 'sql/operator'

module Query
  class QueryExprCandidate
    attr_accessor :op

    def initialize(op)
      @op = Sql::Operator.op(op)
    end

    def parse(field, value, op=@op)
      QueryExprParser.parse("#{field}#{op}#{value}")
    end
  end

  class QueryKeywordParser
    def self.parse(arg)
      self.new(arg).parse
    end

    def initialize(arg)
      @arg = arg.strip
    end

    def atom?
      @arg !~ /[()| ]/
    end

    def body
      @body ||= QueryStruct.new
    end

    def parse
      return self.parse_split_keywords(@arg) unless self.atom?

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

      expr_candidate = QueryExprCandidate.new(@equal_op)
      KeywordMatcher.each do |matcher|
        res = matcher.match(arg, expr_candidate)
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

    def parse_split_keywords(argument)
      CompoundKeywordParser.parse(argument)
    end
  end
end
