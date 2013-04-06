module Query
  module AST
    class Modifier < Term
      attr_reader :modifier, :value

      def initialize(modifier, value)
        @modifier = modifier
        @value = value
      end

      def meta?
        true
      end

      def kind
        @modifier
      end

      def to_s
        "[#{modifier}:#{value}]"
      end

      def to_query_string(paren=false)
        value.to_s
      end
    end
  end
end
