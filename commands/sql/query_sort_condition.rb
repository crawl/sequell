require 'sql/query_sort_field'

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
      av, bv = sort_value(a).to_f, sort_value(b).to_f
      @reverse ? av <=> bv : bv <=> av
    end
    def inspect
      "#{@field}#{@reverse ? ' (reverse)' : ''}"
    end
    def to_s
      inspect
    end
  end
end
