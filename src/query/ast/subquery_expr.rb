module Query
  module AST
    class SubqueryExpr < Term
      def initialize(query)
        @arguments = [query]
        query.subquery_expression = true
      end

      def initialize_copy(o)
        super
        @arguments = @arguments.map(&:dup)
      end

      def empty?
        arguments.empty?
      end

      def query
        @arguments.first
      end

      def kind
        :subquery_expr
      end

      def table_subquery=(table)
        query.table_subquery = table
        query.subquery_expression = !table
      end

      def type
        query ? query.type : Sql::Type.type('*')
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

      def each_value(&block)
        query.each_node { |n|
          if n.value?
            block.call(n)
          else
            n
          end
        }
      end
    end
  end
end
