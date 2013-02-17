require 'sql/field_expr_parser'
require 'sql/field_predicates'

module Sql
  class SummaryField
    include FieldPredicates

    attr_accessor :order, :field, :percentage

    def initialize(s_clause)
      unless s_clause =~ /^([+-]?)(\S+?)(%?)$/
        raise StandardError.new("Malformed summary clause: #{s_clause}")
      end
      @order = $1.empty? ? '+' : $1
      @field = Sql::FieldExprParser.expr($2)
      unless @field.summarisable?
        raise UnknownFieldError.new(@field) unless @field.column
        raise StandardError.new("Cannot summarise by #{@field}")
      end
      @percentage = !$3.empty?
    end

    def dup
      clone = self.dup
      clone.field = self.field.dup
      clone
    end

    def descending?
      @order == '+'
    end

    def sort_field
      "#{order}#{field}"
    end

    def to_s
      "SummaryField[#{order || ''}#{field}#{percentage ? '%' : ''}]"
    end
  end
end
