module Sql
  class Operator
    def self.op(op)
      return op if !op || op.is_a?(self)
      self.new(op)
    end

    def self.operator(o)
      self.op(o)
    end

    def initialize(logical_op)
      @op = logical_op
    end

    def sql_operator
      OPERATORS[@op]
    end

    def textual?
      ['=~','!~','~~', '!~~'].index(@op)
    end

    def equality?
      [ '=', '!=' ].index(@op)
    end

    def relational?
      ['<', '<=', '>', '>='].index(@op)
    end

    def negate
      self.class.new(OPERATOR_NEGATION[@op])
    end

    def equal?
      @op == '='
    end

    def not_equal?
      @op == '!='
    end

    def === (ops)
      if ops.is_a?(Enumerable)
        ops.any? { |op| op == @op }
      else
        @op == ops
      end
    end

    def to_sql
      self.sql_operator
    end

    def to_s
      @op
    end
  end
end
