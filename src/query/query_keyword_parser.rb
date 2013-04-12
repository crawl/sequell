require 'query/keyword_matcher'
require 'query/keyword_defs'
require 'query/operators'
require 'sql/errors'

module Query
  class QueryExprCandidate
    attr_accessor :op

    def initialize(op)
      @op = Query::Operator.op(op)
    end

    def parse(field, value, op=@op)
      Query::AST::Expr.new(op, Sql::Field.field(field), value)
    end
  end

  class KeywordParseError < Sql::ParseError
    def initialize(kw)
      super("No keyword '#{kw}'")
    end
  end

  class QueryKeywordParser
    def self.parse(arg)
      self.new(arg).parse
    end

    def initialize(arg)
      @arg = arg.strip
    end

    def body
      @body ||= Expr.new(:and)
    end

    def parse
      arg = @arg.dup
      @equal_op = '='

      expr_candidate = QueryExprCandidate.new(@equal_op)
      KeywordMatcher.each do |matcher|
        res = matcher.match(arg, expr_candidate)
        if res
          return nil if res == true
          return parse_expr(res, arg) if res.is_a?(String)
          return res
        end
      end
      raise KeywordParseError.new(arg)
    end

    def parse_expr(field, value)
      Query::AST::Expr.new(@equal_op, Sql::Field.field(field), value)
    end
  end
end
