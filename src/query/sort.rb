require 'sql/query_context'
require 'sql/field_predicates'
require 'query/has_expression'

module Query
  class Sort
    attr_reader :expr, :direction

    include HasExpression

    def initialize(expr, direction='DESC')
      unless direction == 'ASC' || direction == 'DESC'
        raise "Bad sort direction: #{direction}"
      end
      @expr = expr
      @expr.bind_ordered_column! if @expr.kind == :field
      @direction = direction
    end

    def unique_valued?
      @expr.kind == :field && @expr.unique_valued?
    end

    def dup
      Sort.new(@expr.dup, @direction.dup)
    end

    def reverse
      Sort.new(@expr.dup, @direction == 'DESC' ? 'ASC' : 'DESC')
    end

    def to_sql(table_set, context=Sql::QueryContext.context)
      "#{@expr.to_sql} #{@direction}"
    end

    def to_s
      "sort(#{@expr} #{@direction})"
    end
  end
end
