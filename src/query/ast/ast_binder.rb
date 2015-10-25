module Query
  module AST
    ##
    # Binds nodes in an AST to their parents and sets up contexts.
    class ASTBinder
      def self.bind(ast)
        self.new(ast).bind
      end

      def self.rebind_field_tables(old_ast, new_ast)
        new_ast.each_field { |f|
          f.table = new_ast if f.table == old_ast
        }
      end

      def initialize(ast)
        @ast = ast
      end

      def bind
        @ast.bind_context(Sql::QueryContext.context)
        bind_from_subqueries(@ast)
        bind_subquery_contexts(@ast)
        bind_outer_queries(@ast)
      end

      private

      def bind_from_subqueries(ast)
        return unless ast.respond_to?(:each_query)
        ast.each_query { |q|
          if q.equal?(ast)
            ast.transform_nodes! { |n|
              if n.respond_to?(:kind) && n.kind == :from_subquery
                ast.from_subquery = n.subquery.tap { |sq|
                  sq.table_subquery = true
                }
                nil
              else
                n
              end
            }
          else
            bind_from_subqueries(q)
          end
        }
      end

      def bind_outer_queries(ast)
        return unless ast.respond_to?(:each_query)
        ast.each_query { |q|
          unless q.equal?(ast)
            q.outer_query = ast
            bind_outer_queries(q)
          end
        }
      end

      def bind_subquery_contexts(ast)
        context = ast.is_a?(Sql::TableContext) ? ast : ast.context
        ast.transform_nodes_breadthfirst! { |node|
          if node.kind == :query
            bind_subquery_contexts(node)
          else
            node.context = context
          end
          node
        }
      end
    end
  end
end
