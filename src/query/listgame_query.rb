require 'query/listgame_parser'
require 'sql/query_list'
require 'sql/crawl_query'

module Query
  # Parslet grammar backed listgame query.
  class ListgameQuery
    def self.parse(default_nick, query, add_context=false)
      self.new(default_nick, QueryString.query(query), add_context)
    end

    attr_reader :default_nick

    def initialize(default_nick, query, add_context)
      @default_nick = default_nick
      @query = query
      @add_context = add_context
    end

    def ast
      @ast ||= Query::ListgameParser.parse(@default_nick, @query, @add_context)
    end

    def primary_query
      @primary_query ||= build_primary_query
    end

    alias :query :primary_query

    def compound_query?
      self.ast.compound_query?
    end

    def secondary_query
      @secondary_query ||= build_secondary_query
    end

    def query_list
      @query_list ||= build_query_list
    end

  private
    def build_primary_query
      Sql::CrawlQuery.new(self.ast.dup)
    end

    def build_secondary_query
      tail_ast = self.ast.tail_ast
      Sql::CrawlQuery.new(tail_ast)
    end

    def build_query_list
      list = ::Sql::QueryList.new
      list << primary_query
      list << secondary_query if compound_query?
      list.filter = ast.filter
      list.order = ast.order
      list
    end
  end
end
