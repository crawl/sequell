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

      def filter_value(query, row)
        case operator.to_s
        when 'not'
          !first.filter_value(query, row)
        when 'and'
          args.all? { |a| a.filter_value(query, row) }
        when 'or'
          args.any? { |a| a.filter_value(query, row) }
        when '='
          left.filter_value(query, row).to_f == right.filter_value(query, row).to_f
        when '!='
          left.filter_value(query, row).to_f != right.filter_value(query, row).to_f
        when '<'
          left.filter_value(query, row).to_f < right.filter_value(query, row).to_f
        when '>'
          left.filter_value(query, row).to_f > right.filter_value(query, row).to_f
        when '>='
          left.filter_value(query, row).to_f >= right.filter_value(query, row).to_f
        when '<='
          left.filter_value(query, row).to_f <= right.filter_value(query, row).to_f
        when '+'
          left.filter_value(query, row).to_f + right.filter_value(query, row).to_f
        when '-'
          left.filter_value(query, row).to_f - right.filter_value(query, row).to_f
        when '*'
          left.filter_value(query, row).to_f * right.filter_value(query, row).to_f
        when '/'
          left.filter_value(query, row).to_f / right.filter_value(query, row).to_f
        end
      end

      def to_s
        arguments.map(&:to_s).join(operator.to_s)
      end
    end
  end
end
