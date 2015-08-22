module Query
  module AST
    ##
    # Represents a subquery used to select columns for the outer query: i.e. a
    # replacement for the primary table.
    class FromSubquery < Term
      attr_reader :subquery

      def initialize(subquery)
        super()
        @subquery = subquery
        @subquery.subquery_expression = false
      end

      def meta?
        true
      end

      def kind
        :from_subquery
      end

      def to_s
        "from:#{subquery.to_s}"
      end
    end
  end
end
