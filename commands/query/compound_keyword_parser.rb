module Query
  class CompoundKeywordParser
    def self.parse(expression)
      self.new(expression).parse
    end

    def initialize(expression)
      @expression = expression
    end

    def parse
      parse_expression(@expression)
    end

    def parse_expression(expr)
      STDERR.puts("parse_expression(#{expr})")
      negated = false
      if parenthesized?(expr)
        negated = expr =~ /^!/
        expr = remove_paren(expr)
      end

      QueryStruct.new(negated ? 'AND' : 'OR', *expr.split('|').map { |or_expr|
        or_expr = "!#{or_expr}" if negated
        QueryKeywordParser.parse(or_expr)
      })
    end

    def atom?(expr)
      expr !~ /[()| ]/
    end

    def parenthesized?(expr)
      expr =~ /^!?\([^()]+\)$/
    end

  private
    def remove_paren(expr)
      expr =~ /^!?\(([^()]+)\)$/ ? $1 : nil
    end
  end
end
