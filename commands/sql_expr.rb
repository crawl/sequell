module SQLExpr
  def self.create(query_node)
    context = LGQueryContext.current

    case query_node.tag
    when :nickselector
      KeywordExpr.expr('name', '=', query_node)
    when :querykeywordexpr
      KeywordExpr.keyword(query_node)
    when :queryorexpr
      node = SQLExpr.new
      node.op = ' OR '
      query_node.each_condition_node do |condition_node|
        node << SQLExpr.create(condition_node)
      end
    when :keyopval
      left_expr = query_node.left_expr_node

      # The context may want to transform key = val expressions. For instance,
      # !lm * rune=slimy => !lm * type=rune noun=slimy
      if context.field_has_transform?(left_expr.text)
        context.transform_field_expr(query_node)
      else
        node = SQLExpr.new
        node.op = query_node.operator
        node << SQLExpr.create(query_node.left_expr_node)
        node << SQLExpr.create(query_node.right_expr_node)
      end
    else
      raise Exception.new("Unknown node type: `#{query_node}`")
    end
  end

  def self.operator(operator)
    node = SQLExpr.new
    node.op = operator
    node
  end

  # Represents a distinct SQL expression, which may be:
  # * Operator expression: <op> <expr> <expr> ...
  # * Atomic: <fieldname>, string, number.
  # * function call: fn(<expr>, <expr>, ...)
  class SQLExpr
    attr_accessor :op, :nodes
    attr_reader :context

    def initialize
      @context = LGQueryContext.current
      @op = nil
      @nodes = []
      @parameter = nil
    end

    def empty?
      @nodes.empty?
    end

    def parameters
      nodes.map { |n| n.parameters }.flatten
    end

    def join_context
      nil
    end

    def << (expr)
      @nodes << expr
    end

    def to_s
      node_strings = nodes.map { |n| n.to_s }.join(', ')
      "Expr(#{@op}, #{node_strings})"
    end

    def to_sql
      "(" + @nodes.map { |n| n.to_sql }.join(' #{@op} ') + ")"
    end
  end

  class FunctionExpr < SQLExpr
    def initialize(function, arguments)
      @function = function
      @nodes = arguments
    end

    def empty?
      false
    end

    def to_s
      to_sql
    end

    def to_sql
      "#{@function}(" + nodes.map { |n| n.to_sql }.join(', ') + ")"
    end
  end

  class ParameterExpr < SQLExpr
    def initialize(parameter_value)
      @parameter_value = parameter_value
    end

    def parameters
      [ @parameter_value ]
    end

    def to_sql
      "?"
    end

    def to_s
      "Par(#{@parameter_value})"
    end
  end

  class FieldNameExpr < SQLExpr
    attr_reader :join_context

    def initialize(field_name)
      @context = LGQueryContext.current
      @field_name = field_name
      @field_def = @context.field(@field_name)
      @join_context = nil

      if !@field_def && @context.autojoin_context
        @field_def = @context.autojoin_context.field(@field_name)
        @context = @context.autojoin_context if @field_def
        @join_context = @context
      end
      unless @field_def
        raise QueryError.new("Unknown field `#{@field_name}`")
      end
    end

    def to_s
      to_sql
    end

    def to_sql
      @context.sql_field_name(@field_def.name)
    end
  end

  class KeywordExpr < SQLExpr
    def self.expr(field_name, operator, value_node)
      node = self.new
      node.op = operator
      node << FieldNameExpr.new(field_name)
      if value_node.negated?
        node.op = Operators.negate(operator)
      end
      node << ParameterExpr.new(value_node.value)
      node
    end

    def self.keyword(keyword_node)

    end
  end
end
