require 'query/ast/term'

module Query
  module AST
    class Extra < Term
      include HasExpression

      attr_reader :ordering

      def initialize(expr, ordering=nil)
        self.expr = expr
        @ordering = ordering.to_s
      end

      def dup
        self.class.new(expr.dup, ordering)
      end

      def kind
        :extra
      end

      def aggregate?
        expr.aggregate?
      end

      def simple_field?
        expr.kind == :field
      end

      def desc?
        !asc?
      end

      def asc?
        ordering == '-'
      end

      def reverse?
        asc?
      end

      def == (other)
        return false unless other.is_a?(Extra)
        other.kind == :extra && other.expr == self.expr
      end

      def to_s
        (asc? ? '-' : '') + expr.to_s
      end
    end
  end
end
