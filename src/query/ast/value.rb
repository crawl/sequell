require 'query/ast/term'

module Query
  module AST
    class Value < Term
      attr_accessor :value

      def self.value(v)
        return v if v.is_a?(Term)
        self.new(v)
      end

      def self.single_quote_string(str, force_quote=false)
        return str unless str.is_a?(String) && (force_quote || str.index(' '))
        "'" + str.gsub(/([\\\\'])/, '\\\\\1') + "'"
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
        (flags[:display_value] || single_quote_string(@value)).to_s
      end

      def single_quote_string(str)
        ::Query::AST::Value.single_quote_string(str, sql_expr?)
      end

      def null?
        value.nil?
      end

      def big_integer?
        self.integer? && (self.value > 2147483647 || self.value < -2147483648)
      end

      def to_sql
        return 'NULL' if null?
        '?' + self.sql_type_qualifier
      end

      def sql_type_qualifier
        value_type = self.type
        return '' if value_type == '*'
        sql_type = value_type.to_sql
        sql_type = 'int' if self.integer?
        sql_type = 'bigint' if self.big_integer?
        return '' unless sql_type
        '::' + sql_type
      end

      def value_type(value)
        return Sql::Type.type('F') if value.is_a?(Float)
        return Sql::Type.type('I') if value.is_a?(Integer)
        Sql::Type.type('*')
      end

      def convert_to_type(type)
        self.value = type.convert(self.value) unless self.null?
        self
      end
    end
  end
end
