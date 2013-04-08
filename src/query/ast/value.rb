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
        @value = value
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
        (flags[:display_value] || display_value(@value)).to_s
      end

      def null?
        value.nil?
      end

      def to_sql
        return 'NULL' if null?
        '?' + self.sql_type_qualifier
      end

      def sql_type_qualifier
        value_type = self.type
        return '' if value_type == '*'
        sql_type = value_type.to_sql
        return '' unless sql_type
        '::' + sql_type
      end

      def value_type(value)
        return Sql::Type.type('F') if value.is_a?(Float)
        return Sql::Type.type('I') if value.is_a?(Integer)
        Sql::Type.type('*')
      end

      def convert_to_type(type)
        self.value = type.convert(self.value)
        self
      end
    end
  end
end
