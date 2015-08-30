require 'query/ast/ordered_list'

module Query
  module AST
    class SummaryList < Term
      include OrderedList

      def initialize(*summary_items)
        @arguments = summary_items
      end

      def initialize_copy(o)
        super
        @arguments = @arguments.map(&:dup)
      end

      def kind
        :summary_list
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
