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
        query_ast.each_query { |q|
          if q.equal?(query_ast)
            apply(q)
          else
            ASTFixup.result(q)
          end
        }
        query_ast
      end

      private

      def apply(q)
        fix_milestone_value_fields!(q)
        fixup_full_query!(q)
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
        q.autojoin_lookup_columns!
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
          if q.exists_query? && !q.flag(:outer_field_reference)
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
        right_col = ast.resolve_column(right, :internal_expr)

        return node unless right_col && left_col.table != right_col.table

        STDERR.puts("**** Join node: #{node}")

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

      def fixup_full_query!(ast)
        return unless ast.kind == :query

        ast.game_number = -1
        ast.transform_nodes! { |node|
          kill_meta_nodes(ast, node)
        }

        if !ast.has_sorts? && ast.needs_sort?
          ast.sorts << Query::Sort.new(ast.context.defsort)
        end

        if ast.sorts
          ast.sorts.each { |sort|
            if sort.aggregate?
              raise "Sort expression cannot be aggregate: #{sort}"
            end
          }
        end

        if !ast.group_order && ast.needs_group_order?
          ast.group_order = ast.default_group_order
        end

        validate_filters(ast, ast.filter)
        validate_filters(ast, ast.group_order)

        ast.bind_tail!
      end

      def validate_filters(ast, filter)
        return unless filter
        filter.each_node { |node|
          if node.kind == :filter_term
            node.validate_filter!(ast.summarise, ast.extra)
          end
        }
      end

      ##
      # Convert milestones value fields X=Y (such as rune=barnacled) into the
      # noun=Y type=X form.
      def fix_milestone_value_fields!(ast)
        STDERR.puts("Fixing milestone value fields for #{ast}")
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

      def kill_meta_nodes(ast, node)
        if node.field_value_predicate? && node.field === 'game'
          ast.game = node.value
          return nil
        end

        return node unless node.meta?
        case node.kind
        when :summary, :extra, :group_order, :keyed_option, :filter_term
          # Don't cull these nodes, cull the parent.
          return node
        when :keyed_option_list
          ast.keys.merge!(node)
        when :sort
          ast.sorts << node
        when :option
          ast.add_option(node)
        when :game_number
          ast.game_number = node.value > 0 ? node.value - 1 : node.value
        when :group_order_list
          ast.group_order = node
        when :summary_list
          raise "Too many grouping terms (extra: #{node})" if ast.summarise
          ast.summarise = node
        when :extra_list
          ast.extra = node.merge(ast.extra)
        else
          raise "Unknown meta: #{node} (#{node.kind})"
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
        ast.operator && ast.arguments.empty?
      end

      def coerce_to_field(node)
        return node if node.kind == :field
        Sql::Field.field(node.value).bind_context(node.context)
      end
    end
  end
end
