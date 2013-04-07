require 'query/ast/term'

module Query
  module AST
    # Expression used to filter query results.
    class FilterExpr < Term
      def self.predicate(op, expr, value)
        self.new(op, expr, value)
      end

      def initialize(op, *args)
        @operator = Query::Operator.op(op)
        @arguments = args
      end

      def kind
        :filter
      end

      def to_s
        arguments.map(&:to_s).join(operator.to_s)
      end
    end
  end
end
