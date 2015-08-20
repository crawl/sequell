require 'query/ast/extra_list'

module Query
  module AST
    class GroupOrderList < ExtraList
      def kind
        :group_order_list
      end

      def meta?
        false
      end

      def to_a
        arguments
      end

      def to_s
        return "" if arguments.empty?
        "o:" + arguments.map(&:to_s).join(',')
      end

      def + (other)
        bind(GroupOrderList.new(*(self.arguments + other.arguments)))
      end

      def << (node)
        self.arguments << bind(node)
      end

      def reverse_order!
        self.arguments.map! { |arg|
          arg.reverse!
        }
        self
      end

      def compare_rows(query, a, b)
        for sort in arguments
          res = sort.compare_rows(query, a, b)
          return res if res != 0
        end
        0
      end
    end
  end
end
