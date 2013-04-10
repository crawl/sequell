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
        #debug{"AST Fixup: #{ast}"}
        ast.game_number = -1

        fix_value_fields!

        ast.transform_nodes! { |node|
          kill_meta_nodes(node)
        }

        if !ast.has_sorts? && ast.needs_sort?
          ast.sorts << Query::Sort.new(@ctx.defsort)
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

        validate_filters(ast.filter)
        validate_filters(ast.group_order)

        ast.bind_tail!

        ast.transform_nodes! { |node|
          collapse_negated_node(node)
        }

        ast.transform! { |node|
          collapse_empty_nodes(node)
        }

        ast.each_node { |node|
          fix_node(node)
        }
      end

      def validate_filters(filter)
        return unless filter
        filter.each_node { |node|
          if node.kind == :filter_term
            node.validate_filter!(ast.summarise, ast.extra)
          end
        }
      end

      def fix_value_fields!
        values = []
        ast.head.map_fields { |field|
          if field.value_key?
            values << field.name
            Sql::Field.field(@ctx.value_field)
          else
            field
          end
        }
        unless values.empty?
          ast.head << Expr.and(*values.map { |v|
              Expr.field_predicate('=', @ctx.key_field, v)
            })
        end
      end

      def kill_meta_nodes(node)
        if node.field_value_predicate? && node.field === 'game'
          ast.game = node.value
          return nil
        end

        return node unless node.meta?
        case node.kind
        when :summary, :extra, :group_order, :keyed_option
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
          raise "Unknown meta: #{node}"
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
          if child && liftup_possible && child.operator == ast.operator
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
    end
  end
end
