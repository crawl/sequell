require 'sql/timestamp_format'
require 'sql/field_expr'
require 'sql/operator'

module Sql
  class FieldPredicate
    def self.predicate(value, operator, field)
      self.new(QueryContext.context, value, operator, field)
    end

    attr_reader :field_expr, :value
    attr_accessor :value_expr, :static, :operator

    def initialize(context, value, operator, field)
      @context = context
      @operator = Sql::Operator.op(operator)
      @value = value
      @field_expr = Sql::FieldExpr.autocase(field, context)
      @static = false
      @value_expr = nil
    end

    def dup
      copy = FieldPredicate.new(@context, @value.dup, @operator.dup,
                                @field_expr.field.dup)
      copy.value_expr = @value_expr
      copy.static = @static
      copy
    end

    def resolved?
      self.field.qualified?
    end

    def static?
      @static
    end

    def field
      self.field_expr.field
    end

    def condition_match?(predicate)
      @field_expr == predicate.field_expr && @operator == predicate.operator
    end

    def simple_expression?
      true
    end

    def field_def
      @field_def ||= @context.field_def(self.field)
    end

    def sql_expr(table_set)
      "#{sql_field_expr(table_set)} #{@operator.sql_operator} " +
        "#{sql_value_placeholder}"
    end

    def sql_field_expr(table_set)
      @field_expr.to_sql(table_set, @context)
    end

    def sql_value_placeholder
      return @value_expr if @value_expr
      return "to_timestamp(?, '#{timestamp_format}')" if date_field?
      "?"
    end

    def sql_value
      return like_escape(@value) if @operator.sql_operator =~ /LIKE/
      @value
    end

    def sql_values
      self.static? ? [] : [self.sql_value]
    end

    def to_sql(table_set, context, parenthesize=false)
      self.sql_expr(table_set)
    end

    def to_s
      "#{@field_expr} #{@operator} #{@value}"
    end

  private
    def like_escape(val)
      val.index('*') || val.index('?') ? val.tr('*?', '%_') : "%#{val}%"
    end

    def date_field?
      self.field_def.date?
    end

    def timestamp_format
      TimestampFormat.format_string(@value)
    end
  end
end
