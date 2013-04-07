require 'query/ast/extra_list'

module Query
  module AST
    class GroupOrderList < ExtraList
      def kind
        :group_order_list
      end

      def to_s
        "o:" + arguments.map(&:to_s).join(',')
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
