require 'query/termlike'

module Query
  module AST
    class WindowPartition < Term
      def initialize(fields, ordering)
        @arguments = fields + [ordering]
      end

      def kind
        :window_partition
      end

      def fields
        arguments[0...-1]
      end

      def ordering
        arguments[-1]
      end

      def to_s
        "partition(#{field_list}, #{ordering.to_s})"
      end

      private

      def field_list
        fields.map(&:to_s).join(',')
      end
    end
  end
end
