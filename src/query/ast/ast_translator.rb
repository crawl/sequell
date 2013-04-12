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
        ast = ASTWalker.map_raw_fields(ast) { |field|
          Sql::Field.field(field.name)
        }

        ast = ASTWalker.map_keywords(ast) { |kw, parent|
          if kw.flag(:keyword_consumed)
            nil
          else
            Cmd::UserKeyword.kill_recursive_keyword {
              ::Query::QueryKeywordParser.parse(kw.value)
            }
          end
        }

        ast = ASTWalker.map_nodes(ast) { |node, parent|
          ::Query::QueryNodeTranslator.translate(node, parent)
        }

        ast = ASTWalker.map_nodes(ast) { |node|
          value_fixup(node)
        }

        ast
      end

      def value_fixup(node)
        node
      end
    end
  end
end
