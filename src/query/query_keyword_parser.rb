require 'query/query_struct'
require 'query/compound_keyword_parser'
require 'query/keyword_matcher'
require 'query/keyword_defs'
require 'sql/operator'
require 'sql/errors'

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

  class KeywordParseError < Sql::ParseError
    def initialize(kw)
      super("Malformed argument: #{kw}")
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
      @equal_op = '='

      expr_candidate = QueryExprCandidate.new(@equal_op)
      KeywordMatcher.each do |matcher|
        res = matcher.match(arg, expr_candidate)
        if res
          return negate(body, negated) if res == true
          return negate(parse_expr(res, arg), negated) if res.is_a?(String)
          return negate(res, negated)
        end
      end
      raise KeywordParseError.new(arg)
    end

    def negate(expr, negated)
      return expr.negate if negated
      expr
    end

    def parse_expr(field, value)
      QueryExprParser.parse("#{field}#{@equal_op}#{value}")
    end

    def parse_split_keywords(argument)
      CompoundKeywordParser.parse(argument)
    end
  end
end
