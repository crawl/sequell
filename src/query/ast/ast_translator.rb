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
        @ast.bind_context(Sql::QueryContext.context)
        bind_subquery_contexts(@ast)
        @ast.transform! { |node|
          translate_ast(node) if node
        }
      end

      private

      def bind_subquery_contexts(ast)
        ast.transform_nodes_breadthfirst! { |node|
          if node.kind == :query
            bind_subquery_contexts(node)
          else
            STDERR.puts("Binding context #{ast.class} to #{node.to_s}")
            node.bind_context(ast)
          end
          node
        }
      end

      def translate_ast(ast)
        ast = ASTWalker.map_kinds(ast, :query) { |q|
          STDERR.puts("Recursing into #{q}")
          ASTTranslator.new(q).apply
        }

        ast = ASTWalker.map_raw_fields(ast) { |field|
          STDERR.puts("Converting field: #{field} to Sql::Field")
          Sql::Field.field(field.name).bind_context(field.context)
        }

        ast = ASTWalker.map_keywords(ast) { |kw, parent|
          if kw.flag(:keyword_consumed)
            nil
          else
            Cmd::UserKeyword.kill_recursive_keyword {
              kw.bind(::Query::QueryKeywordParser.parse(kw.value))
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
