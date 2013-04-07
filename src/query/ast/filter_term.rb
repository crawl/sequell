module Query
  module AST
    class FilterTerm < Term
      def self.term(term)
        self.new(term)
      end

      attr_reader :term
      def initialize(term)
        @term = term
      end

      def kind
        :filter_term
      end

      def to_s
        term.to_s
      end
    end
  end
end
