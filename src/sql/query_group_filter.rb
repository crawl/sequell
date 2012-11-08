module Sql
  class QueryGroupFilter
    def initialize(field, op, value)
      @field = field
      @op = op
      @opproc = FILTER_OPS[op]
      @value = value
    end

    def matches? (row)
      @opproc.call(@field.value(row), @value)
    end
  end
end
