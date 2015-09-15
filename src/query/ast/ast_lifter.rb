module Query
  module AST
    ##
    # Lifts embedded AST nodes that are really AST-global into their
    # corresponding global slots.
    #
    # This is used for terms like x=sc, s=name, o=xl, etc. where although the
    # term is mixed in with filter terms, query options, etc., the term is
    # really a global option on the (sub)query it's in.
    class ASTLifter
      def self.lift(ast)
        self.new(ast).lift
      end

      attr_reader :ast

      def initialize(ast)
        @ast = ast
      end

      def lift
        return ast unless ast.respond_to?(:each_query_depthfirst)
        ast.each_query_depthfirst { |q|
          lift_full_query!(q)
        }
      end

    private

      def lift_full_query!(ast)
        return if ast.flag(:lifted)

        unless ast.kind == :query
          return ast
        end

        ast.transform_nodes! { |node|
          node = kill_meta_nodes(ast, node)
          lift_order_nodes(ast, node)
        }

        lift_having_clause(ast)

        if !ast.has_order? && ast.needs_order?
          ast.order << ast.default_order
        end

        validate_filters(ast, ast.filter)
        validate_filters(ast, ast.order)

        ast.bind_tail!
        ast.flag!(:lifted)
      end

      def lift_having_clause(ast)
        mark_having_clauses(ast.head, nil)
        having_clause = ast.head.bind(Expr.and(*ast.head.arguments.find_all { |n|
                                                 n.flag(:aggregate_expr)
                                               }))
        ast.head.arguments = ast.head.arguments.find_all { |n|
          !n.flag(:aggregate_expr)
        }
        unless having_clause.empty?
          ast.having = having_clause
          unless ast.summarise
            raise("Invalid query: #{ast}; having condition #{having_clause} without summarise")
          end
        end
      end

      def mark_having_clauses(node, parent)
        # Make sure we don't hit any x=foo nodes:
        raise("Unexpected extra node: #{node} after meta-node lift.") if node.kind == :extra_list
        if node.kind == :funcall && node.aggregate?
          parent.flag!(:aggregate_expr) if parent
        end
        node.arguments.each { |arg|
          mark_having_clauses(arg, node)
        }
      end

      def validate_filters(ast, filter)
        return unless filter
        filter.each_node { |node|
          if node.kind == :filter_term
            node.validate_filter!(ast.summarise, ast.extra)
          end
        }
      end

      def lift_order_nodes(ast, node)
        return node unless node && node.kind == :group_order_list && !node.equal?(ast.order)
        ast.order += node.arguments
        nil
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
          ast.order << node.to_group_order_term
        when :option
          ast.add_option(node)
        when :game_number
          ast.game_number = node.value > 0 ? node.value - 1 : node.value
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
    end
  end
end
