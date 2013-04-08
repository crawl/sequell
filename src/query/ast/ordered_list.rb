module Query
  module AST
    module OrderedList
      def dup
        self.class.new(*arguments.map(&:dup))
      end

      def meta?
        true
      end

      def fields
        arguments
      end

      def aggregate?
        arguments.all? { |a| a.aggregate? }
      end

      def merge(other)
        return self unless other
        clone = self.dup
        other.arguments.each { |arg|
          clone.arguments << arg unless clone.arguments.include?(arg)
        }
        clone
      end

      def primary_type
        self.first.type
      end

      def default_group_order
        order = self.first.reverse? ? '-' : ''
        GroupOrderList.new(
          if primary_type.date?
            GroupOrderTerm.new(FilterTerm.new('.'),
                               self.first.reverse? ? '' : '-')
          else
            GroupOrderTerm.new(FilterTerm.new('n'), order)
          end
        )
      end
    end
  end
end
