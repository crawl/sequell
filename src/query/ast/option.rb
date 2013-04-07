require 'query/ast/term'

module Query
  module AST
    class Option < Term
      attr_reader :name

      def initialize(name, arguments)
        @name = name
        @arguments = arguments || []
      end

      def meta?
        true
      end

      def kind
        :option
      end

      def has_args?
        !arguments.empty?
      end

      def to_s
        (["-#{name}"] + @arguments).select { |x| !x.empty? }.join(':')
      end
    end
  end
end
