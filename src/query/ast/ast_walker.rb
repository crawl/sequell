require 'set'

module Query
  module AST
    class ASTWalker
      def self.map_nodes(ast, condition=nil, &block)
        pre = ast.dup
        ast.arguments = ast.arguments.map { |arg|
          map_nodes(arg, condition, &block)
        }.compact
        if !condition || condition.call(ast)
          return block.call(ast)
        end
        ast
      end

      def self.each_node(ast, condition=nil, &block)
        ast.arguments.each { |arg|
          each_node(arg, condition, &block)
        }
        if !condition || condition.call(ast)
          return block.call(ast)
        end
        ast
      end

      def self.map_predicates(ast, &block)
        map_nodes(ast, lambda { |node| node.type.boolean? }, &block)
      end

      def self.map_kinds(ast, kinds, &block)
        kinds = Set.new([kinds]) unless kinds.is_a?(Set)
        map_nodes(ast, lambda { |node| kinds.include?(node.kind) }, &block)
      end

      def self.each_kind(ast, kinds, &block)
        kinds = Set.new([kinds]) unless kinds.is_a?(Set)
        each_node(ast, lambda { |node| kinds.include?(node.kind) }, &block)
      end

      def self.map_fields(ast, &block)
        map_kinds(ast, :field, &block)
      end

      def self.each_field(ast, &block)
        each_kind(ast, :field, &block)
      end

      def self.map_keywords(ast, &block)
        map_kinds(ast, :keyword, &block)
      end

      def self.map_values(ast, &block)
        map_kinds(ast, :value, &block)
      end
    end
  end
end
