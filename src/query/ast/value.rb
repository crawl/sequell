require 'query/ast/term'

module Query
  module AST
    class Value < Term
      attr_reader :value

      def initialize(value)
        @value = value.to_s
      end

      def kind
        :value
      end

      def type
        value_type(@value)
      end

      def to_s
        @value.to_s.inspect
      end

      def value_type
        '*'
      end
    end
  end
end
