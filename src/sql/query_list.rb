module Sql
  class QueryList < Array
    attr_accessor :order, :filter

    def ast
      self.primary_query.ast
    end

    def stub_message
      self.primary_query.stub_message
    end

    def result_prefix_title
      ast.result_prefix_title
    end

    def grouping_query?
      self.primary_query.grouping_query?
    end

    def group_count
      self.primary_query.group_count
    end

    def query_groups
      self.primary_query.query_groups
    end

    def ratio_query?
      self.size == 2
    end

    alias :compound_query? :ratio_query?

    def ctx
      primary_query.ctx
    end

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
