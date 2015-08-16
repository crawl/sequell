require 'query/ast/ast_walker'

module Query
  module Termlike
    attr_accessor :arguments
    attr_accessor :context
    attr_reader :alias

    ##
    # Sets an alias for this term, which may be used as the SQL column alias
    # when selecting this term.
    def alias=(new_alias)
      @alias = new_alias if new_alias && !new_alias.empty?
    end

    ##
    # Returns the primary body predicate for this term. In most cases the term
    # is its own head, but :query objects return their actual WHERE predicate
    # here.
    #
    # You mainly want to use head if you want to explicitly visit a thing's
    # children: QueryAST objects have no arguments, so applying ASTWalker to a
    # QueryAST will just visit the QueryAST itself. Applying ASTWalker to a
    # term's head guarantees descending into the term's children.
    def head
      self
    end

    ##
    # Binds this term to a context, if not already bound. This does not affect
    # children of this term.
    #
    # bind_context explicitly declines to modify an existing binding to a
    # context. To force-overwrite, use context=.
    def bind_context(ctx)
      self.context = ctx unless self.context
      self
    end

    ##
    # Binds a term to use the same context as this term, recursively. Does
    # nothing if this term is not bound.
    def bind(term)
      return term unless term
      ctx = self.context
      return unless ctx
      ::Query::AST::ASTWalker.each_node(term.head) { |n|
        n.bind_context(ctx)
      }
      # Bind the term explicitly for terms where term.head != term:
      term.bind_context(ctx)
      term
    end

    def next_sibling(parent)
      return nil unless parent
      parent.child_offset_from(self, 1)
    end

    def each_query(&block)
      Query::AST::ASTWalker.each_kind(self, :query, &block)

      # Cheat and call the block on ourselves as well, even if this is not a
      # query.
      if self.kind != :query
        block.call(self)
      end
    end

    def child_offset_from(child, offset)
      return nil unless arguments
      index = arguments.find_index { |arg| arg.eql?(child) }
      return nil unless index
      arguments[index + offset]
    end

    def flag(key)
      @flags && @flags[key]
    end

    def flags
      @flags ||= { }
    end

    def with_flags(flags)
      return self if flags.empty?
      self.each_node { |node| node.with_flags(flags) unless node.equal?(self) }
      self.flags.merge!(flags)
      self
    end

    def flag!(flag_name, value=true)
      self.flags[flag_name] = value
      self
    end

    def recursive_flag!(flag_name)
      self.each_node { |node| node.flag!(flag_name) }
      self
    end

    def sql_expr?
      flag(:sql_expr)
    end

    def negatable?
      false
    end

    def value?
      false
    end

    def args
      self.arguments
    end

    def empty?
      arguments.empty?
    end

    def aggregate?
      arguments.any?(&:aggregate?)
    end

    def display_value(raw_value, display_format=nil)
      self.type.display_value(raw_value, display_format)
    end

    def boolean?
      self.type.boolean?
    end

    def equality?
      self.operator && self.operator.equality?
    end

    def empty?
      self.operator && self.arguments.empty?
    end

    def value
      self.right.value if self.right && self.right.kind == :value
    end

    def value=(new_value)
      self.right.value = new_value
    end

    def kind
      :termlike
    end

    def arity
      arguments.size
    end

    def left
      arguments[0]
    end

    def left=(r)
      arguments[0] = r
    end

    alias :first :left

    def right
      arguments[1]
    end

    def right=(r)
      arguments[1] = r
    end

    def single_argument?
      operator && arguments.size == 1
    end

    ##
    # Returns true if this is a function or expr of a field and a value.
    def field_value?
      arguments.size == 2 &&
        self.left.kind == :field &&
        self.right.kind == :value
    end

    ##
    # Returns true if this is a function or expr of two fields.
    def field_field?
      arguments.size == 2 &&
        self.left.kind == :field &&
        self.right.kind == :field
    end

    ##
    # Returns the first argument iff it is a field.
    def field
      self.left if self.left && self.left.kind == :field
    end

    ##
    # Assign the first argument to the given expression.
    def field=(field)
      self.arguments[0] = field
    end

    ##
    # Returns true if this is a predicate function or expr of a field and a value
    def field_value_predicate?
      boolean? && field_value?
    end

    ##
    # Returns true if this is a predicate function or expr of a field and a field
    def field_field_predicate?
      boolean? && field_field?
    end

    def field_equality?
      self.operator && self.operator.equality? && self.arity == 2 &&
        self.left.kind == :field
    end

    def field_value_equality?
      field_equality? && self.right.kind == :value
    end

    # Given a value, converts it into a value that can be simply
    # compared with <, based on the type of this term.
    def comparison_value(raw_value)
      self.type.comparison_value(raw_value)
    end

    def map_nodes_as!(mapper, *args, &block)
      self.arguments = self.arguments.map { |arg|
        Query::AST::ASTWalker.send(mapper, arg, *args, &block)
      }.compact
      Query::AST::ASTWalker.send(mapper, self, *args, &block)
    end

    def transform_nodes!(&block)
      self.map_nodes_as!(:map_nodes, &block)
    end

    def transform_nodes_breadthfirst!(&block)
      self.map_nodes_as!(:map_nodes_breadthfirst, &block)
    end

    def transform!(&block)
      block.call(self)
    end

    def map_fields(&block)
      map_nodes_as!(:map_fields, &block)
    end

    def each_field(&block)
      Query::AST::ASTWalker.each_field(self, &block)
    end

    def each(&block)
      self.arguments.each(&block)
    end

    def each_predicate(&block)
      # Do nothing
    end

    def each_node(&block)
      Query::AST::ASTWalker.each_node(self, &block)
    end

    def without(&filter)
      Query::AST::ASTWalker.map_nodes(self.dup, nil, filter) { nil }
    end

    def wrap_if(condition, left, right=left)
      expr = yield
      return left + expr + right if condition
      expr
    end

    def sql_values
      if self.kind == :value
        [self.value].compact
      else
        self.arguments.map(&:sql_values).flatten
      end
    end

    def to_sql_output
      type.coerce_expr(to_sql)
    end

    def to_query_string(paren=false)
      to_s
    end

    def convert_types!
      self
    end

    def convert_to_type(type)
      self
    end
  end
end
