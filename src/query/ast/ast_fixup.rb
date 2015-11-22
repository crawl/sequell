require 'sql/query_context'

module Query
  module AST
    class ASTFixup
      def self.result(ast, fragment=false)
        self.new(ast).result(fragment)
      end

      attr_reader :query_ast, :head

      def initialize(ast)
        @query_ast = ast
        @head = ast.respond_to?(:head) ? ast.head : ast
      end

      def result(fragment=false)
        apply_recursive(query_ast)

        # This must happen after the initial fixup, since lifting extra fields is
        # critical to correct autojoining.
        autojoin_recursive(query_ast)
        query_ast
      end

      private

      def apply_recursive(query_ast)
        query_ast.each_query { |q|
          if q.equal?(query_ast)
            apply(q)
          else
            apply_recursive(q)
          end
        }
      end

      def autojoin_recursive(query_ast)
        query_ast.each_query { |q|
          if q.equal?(query_ast)
            q.autojoin_lookup_columns! if q.kind == :query
          else
            autojoin_recursive(q)
          end
        }
      end

      def apply(q)
        fix_milestone_value_fields!(q)
        lift_join_conditions!(q)
        autojoin_exists_queries(q)

        q.transform_nodes! { |node|
          collapse_negated_node(node)
        }

        q.transform! { |node|
          collapse_empty_nodes(node)
        }

        q.each_node { |node|
          fix_node(node)
        }
        bind_subquery_game_type(q)
        q.ast_meta_bound = true if q.respond_to?(:ast_meta_bound=)
      end

      def bind_subquery_game_type(ast)
        return unless ast.kind == :query
        ast.join_tables.each { |jt|
          jt.game = ast.game
          bind_subquery_game_type(jt)
        }
      end

      def lift_join_conditions!(ast)
        ast.transform_nodes_breadthfirst! { |node|
          if node.kind == :query && node.table_subquery?
            n = lift_join_conditions!(node)
            if ast.context.table_alias?(n.subquery_alias)
              raise StandardError.new("Subquery alias for #{n} conflicts with context.")
            end
            if n
              ast.add_join_table(n)
            end

            nil
          else
            node
          end
        }
        bind_joins!(ast)
      end

      ##
      # For any exists query that is so tactless as to not specify an outer
      # query column condition, force a gid=outer:gid on it.
      def autojoin_exists_queries(ast)
        ast.each_query { |q|
          if q.kind == :query && q.exists_query? && !q.flag(:outer_field_reference)
            gid_autojoin_exists(ast)
          end
        }
      end

      def gid_autojoin_exists(ast)
        ast.head << Query::AST::Expr.field_predicate('=',
                                                     Sql::Field.field('gid').bind_context(ast),
                                                     Sql::Field.field('outer:gid').bind_context(ast))
        ast.flag!(:outer_field_reference)
      end

      def bind_joins!(ast)
        return ast unless ast.kind == :query
        ast.transform_nodes! { |node|
          bind_join_condition(ast, node)
        }
      end

      ##
      # If the node is a predicate joining two tables, lift it to the special
      # list of join_conditions.
      def bind_join_condition(ast, node)
        return node unless node.field_value_predicate? || node.field_field_predicate?

        left_col = ast.resolve_column(node.left, :internal_expr)
        return node unless left_col
        right = coerce_to_field(node.right)
        right_col = right && ast.resolve_column(right, :internal_expr)

        return node unless right_col && left_col.table != right_col.table

        #STDERR.puts("**** Join node: #{node}")
        outer = ast.outer_query
        if left_col.table.equal?(outer) || right_col.table.equal?(outer)
          node.right = right
          ast.flag!(:outer_field_reference)
          return node
        end

        #node.left.table = left_col.table
        #right.table = right_col.table
        node.right = right

        ast.join_conditions << node

        nil
      end

      ##
      # Convert milestones value fields X=Y (such as rune=barnacled) into the
      # noun=Y type=X form.
      def fix_milestone_value_fields!(ast)
        values = []
        ast.head.map_fields { |field|
          if field.value_key?
            values << field.name
            Sql::Field.field(field.context.value_field).bind_context(field.context)
          else
            field
          end
        }
        unless values.empty?
          ast.head << Expr.and(*values.map { |v|
              Expr.field_predicate('=', ast.context.key_field, v)
            })
        end
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
        liftup_possible = ast.operator && ast.operator.can_coalesce?
        ast.arguments = ast.arguments.map { |child|
          child = collapse_empty_nodes(child)
          if child && liftup_possible && child.operator == ast.operator && ast.operator.commutative?
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

      def fix_node(node)
        if node.value?
          node.value = node.value.gsub('_', ' ') if node.value.is_a?(String)
        end

        # Fix LIKE expressions:
        if (node.operator == '=~' || node.operator == '!~') &&
            node.right.value? && !node.right.flags[:display_value]
          node.right.flag!(:display_value, node.right.value)
          node.right.value = like_escape(node.right.value)
        end
        node.convert_types!
      end

      def like_escape(val)
        val.index('*') || val.index('?') ? val.tr('*?', '%_') : "%#{val}%"
      end

      def ast_collapsible?(ast)
        ast.single_argument? && ast.operator && ast.operator.arity == 0
      end

      def ast_empty?(ast)
        ast.empty? || (ast.operator && ast.arguments.empty?)
      end

      def coerce_to_field(node)
        return node if node.kind == :field
        return nil if node.flag(:quoted_string)
        return nil unless node.value.is_a?(String)
        Sql::Field.field(node.value).bind_context(node.context)
      end
    end
  end
end
