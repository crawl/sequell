require 'query/has_expression'

module Query
  module AST
    class ExistsExpr < Term
      include HasExpression

      attr_reader :type

      def initialize(subquery)
        @arguments = [subquery]
        @type = Sql::Type.type('!')
        subquery.exists_query = true
      end

      def resolved?
        true
      end

      def meta?
        false
      end

      def subquery
        @arguments.first
      end

      def to_sql
        "EXISTS(#{subquery.to_sql_output})"
      end

      def to_s
        to_query_string
      end

      def to_query_string(parenthesize=false)
        "exist(#{subquery.to_query_string})"
      end
    end
  end
end
