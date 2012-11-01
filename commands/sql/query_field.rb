module Sql
  class QueryField
    attr_accessor :expr, :field, :calias, :special, :display, :order
    def initialize(field_list, dbexpr, field, display, calias=nil, special=nil)
      @field_list = field_list
      @expr = dbexpr
      @field = field
      @display = display
      @calias = calias
      @special = special
      @context = Sql::QueryContext.context
      @type = @context.field_type(field)
      @order = ''
    end

    def expr(table_set)
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
      if @type
        return (@field == 'dur' ? pretty_duration(value.to_i) :
                @type == 'D' ? pretty_date(value) : value)
      end
      value
    end

    def to_sql(table_set)
      sql_expr = expr(table_set)
      @calias ? "#{sql_expr} AS #{@calias}" : sql_expr
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
