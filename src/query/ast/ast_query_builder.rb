require 'sql/crawl_query'

module Query
  module AST
    class ASTQueryBuilder
      def self.build(nick, ast, tree)
        self.new(nick, ast, tree).build
      end

      def initialize(nick, ast, tree)
        @nick = nick
        @ast = ast
        @tree = tree
      end

      def build
        ::Sql::CrawlQuery.new(@ast, @tree, @nick)
      end
    end
  end
end
