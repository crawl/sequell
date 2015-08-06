module Query
  module AST
    class WindowFuncall < Term
      def initialize(funcall, partition)
        @arguments = [funcall, partition]
      end

      def kind
        :window_funcall
      end

      def funcall
        @arguments[0]
      end

      def partition
        @arguments[1]
      end

      def to_s
        "#{funcall.to_s}::#{partition.to_s}"
      end
    end
  end
end
