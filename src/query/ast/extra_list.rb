require 'query/ast/term'
require 'query/ast/ordered_list'

module Query
  module AST
    class ExtraList < Term
      include OrderedList

      def initialize(*extras)
        @arguments = extras
      end

      def dup
        self.class.new(*arguments.map(&:dup))
      end

      def kind
        :extra_list
      end

      def to_s
        "x=" + arguments.map(&:to_s).join(',')
      end
    end
  end
end
