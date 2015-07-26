require 'set'

module Query
  module AST
    class ASTWalker
      @@debugging = false
      def self.debugging
        old_debug = @debugging
        begin
          @@debugging = true
          yield
        ensure
          @@debugging = old_debug
        end
      end

      def self.debugging?
        @@debugging
      end

      def self.block_call(block, node, parent)
        block.call(node, parent)
      end

      def self.map_nodes_breadthfirst(ast, parent=nil, condition=nil, visit_subqueries=false, &block)
        ASTMapper.new(ast, parent, condition, true, visit_subqueries, block).apply
      end

      def self.map_nodes(ast, parent=nil, condition=nil, visit_subqueries=false, &block)
        ASTMapper.new(ast, parent, condition, false, visit_subqueries, block).apply
      end

      ##
      # Visits each node in the AST that satisfies the condition
      # block, depth-first.
      def self.each_node(ast, parent=nil, condition=nil, visit_subqueries=false, &block)
        return nil if ast.nil?
        ast.arguments.each { |arg|
          each_node(arg, ast, condition, &block)
        }

        if ast.kind == :query && visit_subqueries
          each_node(ast.head, ast, condition, visit_subqueries, &block)
        end

        if !condition || condition.call(ast)
          return block_call(block, ast, parent)
        end
        ast
      end

      def self.find(ast, &block)
        ast.arguments.each { |arg|
          result = find(arg, &block)
          return result if result
        }
        block.call(ast)
      end

      def self.map_predicates(ast, &block)
        map_nodes(ast, nil, Proc.new { |node| node.type.boolean? }, &block)
      end

      def self.map_kinds(ast, kinds, visit_subqueries=false, &block)
        kinds = Set.new([kinds]) unless kinds.is_a?(Set)
        map_nodes(ast, nil, Proc.new { |node| kinds.include?(node.kind) }, visit_subqueries, &block)
      end

      def self.each_kind(ast, kinds, visit_subqueries=false, &block)
        kinds = Set.new([kinds]) unless kinds.is_a?(Set)
        each_node(ast, nil, Proc.new { |node| kinds.include?(node.kind) }, visit_subqueries, &block)
      end

      def self.map_fields(ast, &block)
        map_kinds(ast, :field, &block)
      end

      def self.map_raw_fields(ast, &block)
        map_kinds(ast, :raw_field, &block)
      end

      def self.each_field(ast, &block)
        each_kind(ast, :field, &block)
      end

      def self.map_keywords(ast, &block)
        map_kinds(ast, :keyword, &block)
      end

      def self.map_values(ast, &block)
        map_kinds(ast, :value, :visit_subqueries, &block)
      end

      def self.map_subqueries(ast, &block)
        map_kinds(ast, :query, &block)
      end
    end

    class ASTMapper
      def initialize(ast, parent, condition, parent_first, visit_subqueries, block)
        @ast = ast
        @parent = parent
        @condition = condition
        @parent_first = parent_first
        @visit_subqueries = visit_subqueries
        @block = block
      end

      def apply
        map(@ast, nil)
      end

    private

      def visit_subqueries?
        @visit_subqueries
      end

      def condition_match?(node)
        !@condition || @condition.call(node)
      end

      def map(node, parent)
        return nil if node.nil?
        if @parent_first
          node = map_node(node, parent)
          map_args(node, parent) if node
        else
          node = map_args(node, parent)
          map_node(node, parent) if node
        end
      end

      def map_node(node, parent)
        if condition_match?(node)
          @block.call(node, parent)
        else
          node
        end
      end

      def map_args(node, parent)
        node.arguments = node.arguments.map { |arg|
          map(arg, node)
        }.compact

        if visit_subqueries? && node.kind == :query
          node.head = map(node.head, node)
        end

        node
      end
    end
  end
end
