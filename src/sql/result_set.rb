module Sql
  class ResultSet < Array
    def self.empty(query)
      self.new(query, 0)
    end

    alias :none? :empty?
    attr_reader :query, :total

    def initialize(query, total, *args)
      super(args)
      @total = total
      @query = query
    end

    def count?
      query.count?
    end
  end
end
