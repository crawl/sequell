require 'query/termlike'

module Query
  module AST
    class WindowPartition < Term
      attr_reader :fields, :ordering

      def initialize(fields, ordering)
        fields = [fields] unless fields.is_a?(Enumerable)
        @fields = fields
        @ordering = ordering
      end

      def kind
        :window_partition
      end

      def arguments
        fields + [ordering].compact
      end

      def arguments=(args)
        @ordering = args.find { |a|
          a.kind == :group_order_list
        }
        @fields = args.find_all { |a| a.kind != :group_order_list }
      end

      def to_s
        if ordering
          "partition(#{field_list}, #{ordering.to_s})"
        else
          "partition(#{field_list})"
        end
      end

      private

      def field_list
        fields.map(&:to_s).join(',')
      end
    end
  end
end
