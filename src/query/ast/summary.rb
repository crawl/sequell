module Query
  module AST
    class Summary < Term
      include HasExpression

      attr_reader :field, :ordering, :percentage

      def initialize(expr, ordering='', percentage=nil)
        @arguments = [expr]
        @ordering = ordering.to_s
        @percentage = percentage && !percentage.strip.empty?
      end

      def dup
        self.class.new(expr.dup, ordering, percentage ? '%' : '')
      end

      def display_value(raw_value, format=nil)
        expr.display_value(raw_value, format)
      end

      def reverse?
        @ordering == '-'
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
    end
  end
end
