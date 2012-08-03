module Sql
  class QueryResult
    attr_accessor :index, :count, :result, :query

    alias :n :index

    def self.none(query)
      self.new(nil, nil, nil, query)
    end

    def initialize(index, count, result, query=nil)
      @index = index
      @count = count || 0
      @result = result
      @query = query
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
      fieldmap = row_to_fieldmap(@result)
      if @query
        fieldmap =
          add_extra_fields_to_xlog_record(@query.extra_fields, fieldmap)
      end
      fieldmap
    end
  end
end
