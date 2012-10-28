require 'sql/timestamp_format'
require 'sql/field'
require 'sql/operator'

module Sql
  class FieldPredicate
    def self.predicate(value, operator, field)
      self.new(QueryContext.context, value, operator, field)
    end

    attr_reader :field, :operator, :value

    def initialize(context, value, operator, field)
      @context = context
      @field = Sql::Field.field(field)
      @operator = Sql::Operator.op(operator)
      @value = value
    end

    def simple_expression?
      true
    end

    def field_def
      @field_def ||= @context.field_def(@field)
    end

    def sql_expr(table_set)
      "#{sql_field_expr(table_set)} #{@operator.sql_operator} " +
        "#{sql_value_placeholder}"
    end

    def sql_field_expr(table_set)
      @context.dbfield(@field, table_set)
    end

    def sql_value_placeholder
      return "to_timestamp(?, '#{timestamp_format}')" if date_field?
      "?"
    end

    def sql_value
      return like_escape(@value) if @operator =~ /LIKE/
      @value
    end

    def sql_values
      [self.sql_value]
    end

    def to_sql(table_set, context, parenthesize=false)
      self.sql_expr(table_set)
    end

    def to_s
      "#{@field.name}#{@op}#{@value}"
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
