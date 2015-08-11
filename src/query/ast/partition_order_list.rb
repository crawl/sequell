require 'query/ast/group_order_list'

module Query
  module AST
    class PartitionOrderList < GroupOrderList
      def self.from_group_order(group_order)
        self.new(*group_order.arguments)
      end

      def kind
        :partition_order_list
      end

      def meta?
        false
      end

      def to_sql
        "ORDER BY " + arguments.map(&:to_sql).join(', ')
      end
    end
  end
end
