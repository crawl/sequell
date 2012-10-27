module Sql
  class QueryList < Array
    attr_accessor :ctx, :sorts, :filters

    def primary_query
      self[0]
    end

    def with_context
      self[0].with_contexts do
        yield
      end
    end
  end
end
