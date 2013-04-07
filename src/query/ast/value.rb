require 'query/ast/term'

module Query
  module AST
    class Value < Term
      attr_accessor :value

      def self.value(v)
        return v if v.is_a?(self)
        self.new(v)
      end

      def initialize(value)
        @value = value.to_s
      end

      def kind
        :value
      end

      def value?
        true
      end

      def type
        value_type(@value)
      end

      def to_s
        @value.to_s
      end

      def to_sql
        '?'
      end

      def value_type(value)
        Sql::Type.type('*')
      end
    end
  end
end
