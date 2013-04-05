require 'query/ast/ast_walker'

module Query
  module Termlike
    def kind
      :termlike
    end

    def arity
      arguments.size
    end

    def left
      arguments[0]
    end

    alias :first :left

    def right
      arguments[1]
    end

    def single_argument?
      operator && arguments.size == 1
    end

    def field_value?
      self.arity == 2 && self.left.kind == :field && self.right.kind == :value
    end

    def field_equality?
      self.operator && self.operator.equality? && self.arity == 2 &&
        self.left.kind == :field
    end

    def field_value_equality?
      field_equality? && self.right.kind == :value
    end

    def map_nodes_as!(mapper, *args, &block)
      self.arguments = self.arguments.map { |arg|
        Query::AST::ASTWalker.send(mapper, arg, *args, &block)
      }.compact
      Query::AST::ASTWalker.send(mapper, self, *args, &block)
    end

    def map_fields(&block)
      map_nodes_as!(:map_fields, &block)
    end

    def each_field(&block)
      Query::AST::ASTWalker.each_field(self, &block)
    end

    def each_node(&block)
      Query::AST::ASTWalker.each_node(self, &block)
    end
  end
end
