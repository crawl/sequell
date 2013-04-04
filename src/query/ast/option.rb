require 'query/ast/term'

module Query
  module AST
    class Option < Term
      attr_reader :name, :args

      def initialize(name, args)
        @name = name
        @args = args || []
      end

      def meta?
        true
      end

      def has_args?
        !@args.empty?
      end

      def to_s
        argstr = @args.empty? ? nil : @args.join(':')
        ["-#{name}", argstr].compact.join(':')
      end
    end
  end
end
