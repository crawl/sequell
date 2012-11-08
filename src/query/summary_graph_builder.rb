module Query
  class SummaryGraphBuilder
    def self.build(query_group, options, query_args)
      require 'formatter/graph_summary'
      title = ("!#{Sql::QueryContext.context.table_alias} " +
               query_args.join(' '))
      Formatter::GraphSummary.new(query_group, title, options)
    end
  end
end
