require 'sql/query_context'
require 'sql/field_predicates'

module Query
  class Sort
    attr_reader :field, :direction

    include Sql::FieldPredicates

    def initialize(field, direction='DESC')
      unless direction == 'ASC' || direction == 'DESC'
        raise "Bad sort direction: #{direction}"
      end
      @field = field
      @direction = direction
    end

    def dup
      Sort.new(@field.dup, @direction.dup)
    end

    def reverse
      Sort.new(@field, @direction == 'DESC' ? 'ASC' : 'DESC')
    end

    def to_sql(table_set, context=Sql::QueryContext.context)
      "#{@field.to_sql} #{@direction}"
    end

    def to_s
      "sort(#{@field} #{@direction})"
    end
  end
end
