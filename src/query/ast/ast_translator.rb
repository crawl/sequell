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
        @ast.transform_nodes! { |node|
          translate_ast(node)
        }
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
