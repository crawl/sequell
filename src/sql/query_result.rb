module Sql
  class QueryResult
    attr_accessor :index, :count, :result, :query

    alias :n :index

    def self.none(query)
      self.new(nil, nil, nil, query)
    end

    def initialize(index, count, result, query)
      @index = index
      @count = count || 0
      @result = result
      @query = query
    end

    def option(key)
      query.option(key)
    end

    def milestone?
      game['milestone']
    end

    def game_key
      @game_key ||= game['game_key']
    end

    def milestone_game
      raise StandardError, "Not a milestone" unless milestone?
      @milestone_game ||= self.game_key && sql_game_by_key(self.game_key)
    end

    def qualified_index
      if index < count
        "#{index}/#{count}"
      else
        index.to_s
      end
    end

    def query_arguments
      @query && @query.argstr
    end

    def empty?
      @result.nil?
    end

    def none?
      self.empty?
    end

    def fieldmap
      @fieldmap ||= row_fieldmap
    end

    alias :game :fieldmap

  private
    def row_fieldmap
      return nil unless @result
      fieldmap = @query.row_to_fieldmap(@result)
      fieldmap =
        add_extra_fields_to_xlog_record(@query.extra_fields, fieldmap)
      fieldmap
    end
  end
end
