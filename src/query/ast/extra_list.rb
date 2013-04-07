require 'query/ast/term'

module Query
  module AST
    class ExtraList < Term
      def initialize(*extras)
        @arguments = extras
      end

      def dup
        self.class.new(*arguments.map(&:dup))
      end

      def kind
        :extra_list
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

      def to_s
        "x=" + arguments.map(&:to_s).join(',')
      end
    end
  end
end
