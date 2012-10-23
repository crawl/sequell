module Query
  class QueryListBuilder
    def self.build(primary_query, sorts, group_filters)
      query_list = QueryList.new
      query_list.sorts = sorts
      query_list.filters = group_filters
      query_list << primary_query
      query_list
    end
  end
end
