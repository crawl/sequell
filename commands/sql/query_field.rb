require 'sql/field_expr_parser'
require 'sql/field_predicates'

module Sql
  class QueryField
    include FieldPredicates

    attr_accessor :expr, :field, :calias, :special, :display, :order
    def initialize(field_list, dbexpr, field, display, calias=nil, special=nil)
      @field_list = field_list
      @expr = dbexpr
      @field = FieldExprParser.expr(field)
      @display = display
      @calias = calias
      @special = special
      @context = Sql::QueryContext.context
      @order = ''
    end

    def simple_field?
      !aggregate? && @field.simple_field?
    end

    def expr
      field_expr = @field.to_sql if @field
      @expr ? @expr.sub('%s', field_expr.to_s) : field_expr
    end

    def default_sort
      QuerySortCondition.new(@field_list, @display, @order == '-')
    end

    def descending?
      @order == '+'
    end

    def format_value(value)
      if self.type
        return (field === 'dur' ? pretty_duration(value.to_i) :
                self.date? ? pretty_date(value) : value)
      end
      value
    end

    def to_sql
      sql_expr = self.expr
      @calias ? "#{sql_expr} AS #{@calias}" : sql_expr
    end

    def to_s
      return @expr unless @field
      @field.to_s
    end

    def aggregate?
      return @expr && @expr =~ /\w+\(/
    end

    def count?
      return expr.downcase == 'count(*)'
    end

    def perc?
      return count?() && special() == :percentage
    end
  end
end
