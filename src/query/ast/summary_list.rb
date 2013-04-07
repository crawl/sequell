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

      def primary_type
        self.first.type
      end

      def default_group_order
        GroupOrderList.new(
          if primary_type.text? || primary_type.date?
            GroupOrderTerm.new(FilterTerm.new('.'), '-')
          else
            GroupOrderTerm.new(FilterTerm.new('n'))
          end
        )
      end

      def to_s
        "s=" + arguments.map(&:to_s).join(",")
      end
    end
  end
end
