module Query
  module AST
    class FilterValue < Term
      attr_reader :value

      def initialize(value)
        @value = value
      end

      def kind
        :filter_value
      end

      def value?
        true
      end

      def filter_value(query, row)
        @value
      end

      def to_s
        @value
      end
    end
  end
end
