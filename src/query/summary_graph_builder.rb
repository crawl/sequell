module Query
  class SummaryGraphBuilder
    def self.build(query_group, options, query_args)
      require 'formatter/graph_summary'
      title = query_args.to_s
      Formatter::GraphSummary.new(query_group, title, options)
    end
  end
end
