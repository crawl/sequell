require 'query/ast/ast_walker'
require 'query/ast/ast_binder'
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
        ASTBinder.bind(@ast)

        if @ast.respond_to?(:each_query)
          @ast.each_query { |q|
            ASTTranslator.new(q).apply unless q.equal?(@ast)
          }
        end

        @ast.transform! { |node|
          translate_ast(node) if node
        }
      end

      private

      def translate_ast(ast)
        # Convert Query::AST::Field instances to Sql::Field instances
        ast = ASTWalker.map_raw_fields(ast) { |field|
          Sql::Field.field(field.name).bind_context(field.context)
        }

        ast = ASTWalker.map_keywords(ast) { |kw, parent|
          if kw.flag(:keyword_consumed)
            nil
          else
            Cmd::UserKeyword.kill_recursive_keyword {
              kw.bind(::Query::QueryKeywordParser.parse(kw.context, kw.value))
            }
          end
        }

        ast = ASTWalker.map_nodes(ast) { |node, parent|
          node.bind(::Query::QueryNodeTranslator.translate(node, parent))
        }

        ast
      end
    end
  end
end
