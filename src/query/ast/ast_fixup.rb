require 'sql/query_context'

module Query
  module AST
    class ASTFixup
      def self.result(nick, ast)
        self.new(nick, ast).result
      end

      attr_reader :nick, :ast

      def initialize(nick, ast)
        @nick = nick
        @ast = ast
        @ctx = Sql::QueryContext.context
      end

      def result
        STDERR.puts("Fixing: #{ast}")
        ast.game_number = -1

        ast.transform_nodes! { |node|
          kill_meta_nodes(node)
        }

        if !ast.has_sorts? && ast.needs_sort?
          ast.sorts << Query::Sort.new(@ctx.defsort)
        end

        ast.transform_nodes! { |node|
          collapse_negated_node(node)
        }

        ast.transform! { |node|
          collapse_empty_nodes(node)
        }
      end

      def kill_meta_nodes(node)
        return node unless node.meta?
        case node.kind
        when :option
          ast.options << node
        when :game_number
          ast.game_number = node.value > 0 ? node.value - 1 : node.value
        else
          raise "Unknown node: #{node}"
        end

        nil
      end

      def collapse_negated_node(node)
        if node.operator == :not && node.arity == 1 &&
            node.arguments.all? { |arg| arg.negatable? }
          return node.first.negate
        end
        node
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
