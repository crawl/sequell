require 'sql/query_context'

module Query
  class Sort
    attr_reader :field, :direction

    def initialize(field, direction='DESC')
      unless direction == 'ASC' || direction == 'DESC'
        raise "Bad sort direction: #{direction}"
      end
      @field = field
      @direction = direction
    end

    def reverse
      Sort.new(@field, @direction == 'DESC' ? 'ASC' : 'DESC')
    end

    def to_sql(table_set, context=Sql::QueryContext.context)
      "#{context.dbfield(@field, table_set)} #{@direction}"
    end

    def to_s
      "sort(#{@field} #{@direction})"
    end
  end
end
