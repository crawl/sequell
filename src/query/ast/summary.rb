module Query
  module AST
    class Summary < Term
      attr_reader :field, :ordering, :percentage

      def initialize(expr, ordering='', percentage=nil)
        @arguments = [expr]
        @ordering = ordering.to_s
        @percentage = percentage && !percentage.strip.empty?
      end

      def expr
        @arguments.first
      end

      def reverse?
        @ordering == '-'
      end

      def meta?
        true
      end

      def kind
        :summary
      end

      def percentage?
        @percentage
      end

      def to_s
        [@ordering, expr.to_s, @percentage && '%'].select { |x| x }.join('')
      end

      def to_sql(*args)
        expr.to_sql(*args)
      end
    end
  end
end
