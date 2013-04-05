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
        @ast.transform! { |node|
          translate_ast(node)
        }
      end

      def translate_ast(ast)
        ast = ASTWalker.map_keywords(ast) { |kw|
          ::Query::QueryKeywordParser.parse(kw.value)
        }

        ast = ASTWalker.map_nodes(ast) { |node|
          ::Query::QueryNodeTranslator.translate(node)
        }

        ast = ASTWalker.map_nodes(ast) { |node|
          value_fixup(node)
        }
      end

      def value_fixup(node)
        node
      end
    end
  end
end
