require 'sql/type'
require 'query/termlike'

module Query
  module AST
    class Term
      attr_accessor :context, :arguments

      include ::Query::Termlike

      def initialize
        @arguments = []
      end

      def operator
        nil
      end

      def arguments
        @arguments || []
      end

      def kind
        :generic
      end

      def type
        Sql::Type.type('*')
      end

      def unit
        self.type.unit
      end

      def to_query_string(parenthesize=false)
        self.to_s
      end

      def value?
        false
      end

      # A thing that is not really a term, such as an option.
      def meta?
        false
      end

      def negate
        return self if meta?
        raise "Unsupported operation"
      end

      def paren_wrapped(text, wrap=false)
        if wrap
          "(#{text})"
        else
          text
        end
      end
    end
  end
end
