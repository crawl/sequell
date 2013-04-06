module Query
  module AST
    class Field < Term
      attr_reader :name

      def initialize(name)
        @name = name.to_s
      end

      def kind
        :raw_field
      end

      def to_s
        @name
      end
    end
  end
end
