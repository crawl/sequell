module Query
  module AST
    class Term
      attr_accessor :context, :arguments

      def initialize
        @arguments = []
      end

      def operator
        nil
      end

      def arguments
        []
      end

      def kind
        :generic
      end

      def first
        arguments.first
      end

      def single_argument?
        operator && arguments.size == 1
      end

      def type
        '*'
      end

      def value?
        false
      end

      # A thing that is not really a term, such as an option.
      def meta?
        false
      end

      def negate
        return self if meta?
        raise "Unsupported operation"
      end
    end
  end
end
