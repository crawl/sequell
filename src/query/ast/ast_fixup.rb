module Query
  module AST
    class ASTFixup
      def apply(ast)
        STDERR.puts("Fixing: #{ast}")
        ast.head = collapse_empty_nodes(ast.head)
        ast.tail = collapse_empty_nodes(ast.tail)
        ast
      end

      def collapse_empty_nodes(ast)
        return nil unless ast
        lifted_nodes = []
        liftup_possible = ast.operator && ast.operator.commutative?
        ast.arguments = ast.arguments.map { |child|
          child = collapse_empty_nodes(child)
          if liftup_possible && child.operator == ast.operator
            lifted_nodes << child
            nil
          else
            child
          end
        }.compact

        lifted_nodes.each { |lifted|
          ast.arguments += lifted.arguments
        }
        return ast.first if ast_collapsible?(ast)
        return nil if ast_empty?(ast)
        ast
      end

      def ast_collapsible?(ast)
        ast.single_argument? && ast.operator && ast.operator.arity == 0
      end

      def ast_empty?(ast)
        ast.operator && ast.arguments.empty?
      end
    end
  end
end
