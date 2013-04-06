require 'query/ast/term'

module Query
  module AST
    class Extra < Term
      attr_reader :ordering

      def initialize(expr, ordering=nil)
        @arguments = [expr]
        @ordering = ordering.to_s
      end

      def kind
        :extra
      end

      def meta?
        true
      end

      def desc?
        !asc?
      end

      def asc?
        ordering == '-'
      end

      def expr
        self.first
      end

      def to_s
        (asc? ? '-' : '') + expr.to_s
      end
    end
  end
end
