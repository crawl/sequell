module Query
  module AST
    class SubqueryExpr < Term
      def initialize(query)
        @arguments = [query]
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
    end
  end
end
