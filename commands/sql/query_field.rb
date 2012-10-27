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
      @type = QueryContext.context.field_type(field)
      @order = ''
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

    def to_s
      @calias ? "#{@expr} AS #{@calias}" : @expr
    end

    def aggregate?
      return expr =~ /\w+\(/
    end

    def count?
      return expr.downcase == 'count(*)'
    end

    def perc?
      return count?() && special() == :percentage
    end
  end
end
