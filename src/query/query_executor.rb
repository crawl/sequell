require 'query/listgame_parser'
require 'query/option_executor'
require 'formatter/json_summary'
require 'formatter/text_summary'
require 'formatter/json'
require 'formatter/text'

module Query
  class QueryExecutor
    def self.json(query)
      self.new(force_json(query)).result
    end

    def self.force_json(query)
      query.primary_query.json = true
      query
    end

    attr_reader :query_group, :option_executor
    def initialize(query_group, option_executor=OptionExecutor)
      @query_group = query_group
      @option_executor = option_executor
    end

    def primary
      query_group.primary_query
    end

    alias :q :primary

    def json?
      primary.json?
    end

    def graph?
      q.option(:graph)
    end

    def summary?
      q.summarise?
    end

    def query_result
      @query_result ||= sql_exec_query(q.num, q)
    end

    ##
    # Result must be an object that can be converted into JSON.
    def result
      query_group.with_context do
        if primary.summarise?
          summary_result
        else
          simple_result
        end
      end
    end

  private

    def simple_result
      unless query_result.empty?
        result = option_executor && option_executor.execute(self)
        return result if result
      end
      result_formatter.format(query_result)
    end

    def result_formatter
      if json?
        Formatter::JSON
      else
        Formatter::Text
      end
    end

    def summary_result
      Sql::SummaryReporter.new(query_group, summary_formatter).summary
    end

    def summary_formatter
      case
      when graph?
        graph_summary_formatter
      when json?
        Formatter::JSONSummary
      else
        Formatter::TextSummary
      end
    end

    def graph_summary_formatter
      @graph_summary_formatter ||=
        Query::SummaryGraphBuilder.build(
          query_group,
          q.option(:graph),
          q.title)
    end
  end
end
