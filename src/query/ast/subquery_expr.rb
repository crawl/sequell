module Query
  module AST
    class SubqueryExpr < Term
      def initialize(query)
        @arguments = [query]
        query.subquery_expression = true
      end

      def query
        @arguments.first
      end

      def kind
        :subquery_expr
      end

      def to_sql
        "(" + query.to_sql + ")"
      end

      def inspect
        to_s
      end

      def to_s
        query.to_s
      end
    end
  end
end
