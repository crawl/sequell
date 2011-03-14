module SQLExprs
  def self.create(query_node)
    context = LGQueryContext.current

    case query_node.tag
    when :nickselector
      NickSelectExpr.create(query_node)
    when :querykeywordexpr
      KeywordExpr.keyword(query_node)
    when :queryorexpr
      node = SQLExpr.new
      node.op = ' OR '
      query_node.each_condition_node do |condition_node|
        node << self.create(condition_node)
      end
      node
    when :queryfield
      FieldNameExpr.new(query_node.text)
    when :sloppyexpr
      ParameterExpr.new(query_node.text)
    when :keyopval
      left_expr = query_node.left_expr_node
      operator = query_node.operator_node.text
      right_expr = query_node.right_expr_node

      if left_expr.simple_field? && right_expr.simple_value?
        self.field_op_val(left_expr.text, operator, right_expr.text)
      else
        node = SQLExpr.new
        node.op = query_node.operator_node.text
        node << self.create(query_node.left_expr_node)
        node << self.create(query_node.right_expr_node)
        node
      end
    else
      raise Exception.new("Unknown node type: `#{query_node}`")
    end
  end

  def self.anded_exprs(*expr)
    self.group('AND', *expr)
  end

  def self.group(group_op, *expr)
    node = self.operator(group_op)
    node += expr
    node
  end

  def self.field_op_val(field, op, val, skip_further_xforms=nil)
    context = LGQueryContext.current
    # The context may want to transform key = val expressions. For instance,
    # !lm * rune=slimy => !lm * type=rune noun=slimy
    field_name_expr = FieldNameExpr.new(field)
    field_expr =
      !skip_further_xforms &&
      context.field_transform(field_name_expr.canonical_name, op, val)
    if field_expr
      field_expr
    else
      node = SQLExpr.new
      node.op = op
      node << field_name_expr
      node << ParameterExpr.new(val)
      node
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
    attr_accessor :op, :nodes, :parent
    attr_reader :context

    def initialize
      @parent = nil
      @context = LGQueryContext.current
      @op = nil
      @nodes = []
      @parameter = nil
    end

    def negate
      unless op
        raise QueryError.new("Attempt to negate #{self}")
      end
      clone = self.dup
      clone.op = Operators.negate(self.op)
      if Operators.negate_cascades?(self.op)
        clone.nodes = clone.nodes.map { |n| n.negate }
      end
      clone
    end

    def empty?
      @nodes.empty?
    end

    def parameters
      nodes.nil? ? [] : nodes.map { |n| n.parameters }.flatten
    end

    def join_context
      nil
    end

    def << (expr)
      if expr.is_a?(Array)
        raise Exception.new("Attempt to add array as expression node")
      end
      return unless expr

      if @nodes.size == 1 && expr.is_a?(ParameterExpr)
        expr = transform_parameter(expr)
      end
      @nodes << expr
      expr.parent = self
    end

    def transform_parameter(parameter)
      case op
      when '=~', '!~'
        LikeParameterExpr.new(parameter.value)
      else
        parameter
      end
    end

    def + (exprs)
      clone = self.dup
      clone.nodes += exprs.find_all { |e| e }
      clone
    end

    def to_s
      node_strings = nodes.map { |n| n.to_s }.join(op)
    end

    def inspect
      to_s
    end

    def sqlop
      sql_operator = Operators.sql_operator(@op)
      if sql_operator =~ /^[\w ]+$/
        " " + sql_operator + " "
      else
        sql_operator
      end
    end

    def parenthesise?
      op == 'OR' && @parent
    end

    def parenthesise(text)
      "(" + text + ")"
    end

    def to_sql
      if @nodes.size == 1
        child = @nodes[0]
        begin
          child.parent = @parent
          child.to_sql
        ensure
          child.parent = self
        end
      else
        body = @nodes.map { |n| n.to_sql }.join(sqlop)
        body = parenthesise(body) if parenthesise?
        body
      end
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
      @parameter_value = parameter_value.gsub('_', ' ')
    end

    def parameters
      [ @parameter_value ]
    end

    def value
      @parameter_value
    end

    def to_sql
      "?"
    end

    def to_s
      @parameter_value
    end
  end

  class LikeParameterExpr < ParameterExpr
    def parameters
      [ sql_parameter_value ]
    end

    def sql_parameter_value
      if has_glob_metacharacters?(@parameter_value)
        sql_like_value(@parameter_value)
      else
        sql_like_value('*' + @parameter_value + '*')
      end
    end

    def has_glob_metacharacters?(value)
      value.index('*') || value.index('?')
    end

    def sql_like_value(value)
      value.gsub('*', '%').gsub('?', '_')
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

    def canonical_name
      @field_def.name
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
      if keyword_node.nick_keyword?
        # FIXME: Use nickmappings here.
        nick_node = SQLExprs.field_op_val('name', '=', keyword_node.value)
        return keyword_node.negated? ? nick_node.negate : nick_node
      end

      context = LGQueryContext.current
      expr = context.keyword_transform(keyword_node.value)
      unless expr
        message =
          if keyword_node.value == keyword_node.text
            "Bad keyword: `#{keyword_node.text}`"
          else
            "Bad keyword `#{keyword_node.value}` in `#{keyword_node.text}`"
          end
        raise QueryError.new(message)
      end
      keyword_node.negated? ? expr.negate : expr
    end
  end

  class NickSelectExpr < SQLExpr
    def self.create(query_node)
      nick = query_node.value
      if nick == '*'
        if query_node.negated?
          raise QueryError.new("Bad nick selector `#{query_node.text}`")
        end
        return nil
      end
      node = SQLExprs.field_op_val('name', '=', query_node.value)
      query_node.negated? ? node.negate : node
    end
  end
end
