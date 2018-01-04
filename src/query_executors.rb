require 'commands/sql_connection'
require 'commands/game_formatter'

module QueryExecutors
  def self.create_executor(query)
    action_type = query.action_type
    if action_type
      raise "Game actions are unimplemented"
    else
      case
      when query.ratio_query?
        RatioQueryExecutor.new(query)
      when query.summary_query?
        SummaryQueryExecutor.new(query)
      else
        SimpleQueryExecutor.new(query)
      end
    end
  end

  class SQLExecutor
    def initialize(query, query_parameters=nil)
      if query_parameters
        @query_string = query
        @query_parameters = query_parameters
      else
        @query_string = query.query_string
        @query_parameters = query.query_parameters
      end
    end

    def single_value
      SQLConnection.with_connection { |c|
        c.get_first_value(@query_string, @query_parameters)
      }
    end

    def each_row
      SQLConnection.with_connection do |c|
        c.execute(@query_string, @query_parameters) do
          yield
        end
      end
    end

    def do
      SQLConnection.with_connection do |c|
        c.do(@query_string, @query_parameters)
      end
    end
  end

  class SimpleQueryExecutor
    def initialize(query)
      @query = query
    end

    def execute
      count = @query.count_matching_records
      row_record = @query.matching_record
      if not row_record
        puts "No #{query.entity_name}s for #{q.readable_string}."
      else
        GameFormatter.pretty_print_game_n(query.record_index, row_record)
      end
    end
  end
end
