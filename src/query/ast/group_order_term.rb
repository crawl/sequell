require 'query/ast/extra'

module Query
  module AST
    class GroupOrderTerm < Extra
      def kind
        :group_order
      end

      def to_sql
        "#{expr.to_sql} #{order_sql}"
      end

      def cmp_value(query, row)
        value = expr.filter_value(query, row)
        return value.to_s if value == true || value == false
        value
      end

      def compare_rows(q, a, b)
        av, bv = cmp_value(q, a), cmp_value(q, b)
        asc? ? av <=> bv : bv <=> av
      end

      def unique_valued?
        expr.kind == :field && expr.unique_valued?
      end

      private

      def order_sql
        asc? ? 'ASC' : 'DESC'
      end
    end
  end
end
