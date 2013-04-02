require 'query/listgame_parser'

module Query
  # Parslet grammar backed listgame query.
  class ListgameQuery
    def self.parse(query)
      self.new(QueryString.query(query))
    end

    def initialize(query)
      @query = query
      @ast = Query::ListgameParser.parse(@query)
    end
  end
end
