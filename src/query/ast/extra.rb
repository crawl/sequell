require 'query/ast/term'

module Query
  module AST
    class Extra < Term
      attr_reader :ordering

      def initialize(expr, ordering=nil)
        @arguments = [expr]
        @ordering = ordering.to_s
      end

      def dup
        self.class.new(expr.dup, ordering)
      end

      def kind
        :extra
      end

      def meta?
        true
      end

      def type
        expr.type
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

      def expr
        self.first
      end

      def to_s
        (asc? ? '-' : '') + expr.to_s
      end

      def to_sql
        expr.to_sql
      end
    end
  end
end
