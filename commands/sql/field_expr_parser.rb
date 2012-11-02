require 'query/grammar'
require 'sql/field_expr'

module Sql
  class FieldExprParser
    include Query::Grammar
    CAPTURING_FUNCTION_CALL =
      Regexp.new("^(#{FUNCTION})\\((#{FIELD})\\)$", Regexp::IGNORECASE)

    # Given a String, a Field, or a FieldExpr, returns a FieldExpr
    # This is the preferred way to parse a raw string to a field-like
    # object.
    def self.expr(expression, context=Sql::QueryContext.context)
      return nil if expression.nil?

      if expression.respond_to?(:expr?)
        return expression.expr? ? expression : FieldExpr.autocase(expression)
      end

      if expression.to_s =~ CAPTURING_FUNCTION_CALL
        function_expr(context, $1, $2)
      else
        FieldExpr.autocase(expression)
      end
    end

    def self.function_expr(context, function_name, field)
      function_type = context.function_type(function_name)
      raise "Unknown function: #{function_name}" unless function_type
      field_type = Sql::Field.field(field).type
      raise "Unknown field: #{field}" unless field_type
      if function_type != '*' && field_type != function_type
        raise "Cannot apply #{function_name} to #{field}: type mismatch"
      end

      function_def = context.function_def(function_name)
      expr = FieldExpr.new(field, function_def.expr, function_def.return_type)
      expr.function = function_def
      expr
    end
  end
end
