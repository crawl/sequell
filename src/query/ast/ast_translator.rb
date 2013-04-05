require 'query/ast/ast_walker'
require 'query/query_keyword_parser'
require 'query/query_node_translator'

module Query
  module AST
    class ASTTranslator
      def self.apply(ast)
        self.new(ast).apply
      end

      attr_reader :ast

      def initialize(ast)
        @ast = ast
      end

      def apply
        @ast.head = translate_ast(@ast.head)
        @ast.tail = translate_ast(@ast.tail) if @ast.tail
        extract_query_modifiers!
        @ast
      end

      def extract_query_modifiers!
      end

      def translate_ast(ast)
        ASTWalker.map_keywords(ast) { |kw|
          ::Query::QueryKeywordParser.parse(kw.value)
        }

        ASTWalker.map_nodes(ast) { |node|
          ::Query::QueryNodeTranslator.translate(node)
        }
      end
    end
  end
end
