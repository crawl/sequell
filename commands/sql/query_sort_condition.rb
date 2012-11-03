require 'sql/query_sort_field'
require 'date'

module Sql
  class QuerySortCondition
    def initialize(extra, field, reverse=true)
      @reverse = reverse
      @field = QuerySortField.new(field, extra)
    end

    def sort_value(row)
      value = @field.value(row)
    end

    def sort_cmp(a, b)
      av, bv = cmp_value(a), cmp_value(b)
      @reverse ? av <=> bv : bv <=> av
    end

    def cmp_value(x)
      sort_value(x)
    end

    def inspect
      "#{@field}#{@reverse ? ' (reverse)' : ''}"
    end
    def to_s
      inspect
    end
  end
end
