require 'query/listgame_parser'
require 'sql/query_list'

module Query
  # Parslet grammar backed listgame query.
  class ListgameQuery
    def self.parse(default_nick, query)
      self.new(default_nick, QueryString.query(query))
    end

    def initialize(default_nick, query)
      @default_nick = default_nick
      @query = query
    end

    def ast
      @ast ||= Query::ListgameParser.parse(@query)
    end

    def primary_query
      @primary_query ||= build_primary_query
    end

    def query_list
      @query_list ||= build_query_list
    end

  private
    def build_primary_query
      ASTQueryBuilder.build(self.ast)
    end

    def build_query_list
      list = ::Sql::QueryList.new
      list << primary_query
      list
    end
  end
end
