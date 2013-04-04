require 'query/listgame_parser'

module Query
  # Parslet grammar backed listgame query.
  class ListgameQuery
    def self.parse(default_nick, query)
      self.new(default_nick, QueryString.query(query))
    end

    def initialize(default_nick, query)
      @default_nick = default_nick
      @query = query
      @ast = Query::ListgameParser.parse(@query)
    end
  end
end
