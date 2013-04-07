module Query
  module AST
    class SummaryList < Term
      def initialize(*summary_items)
        @arguments = summary_items
      end

      def meta?
        true
      end

      def kind
        :summary_list
      end

      def dup
        self.class.new(*arguments.map { |a| a.dup })
      end

      def multiple_field_group?
        self.arity > 1
      end

      def to_s
        "s=" + arguments.map(&:to_s).join(",")
      end
    end
  end
end
