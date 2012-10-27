require 'sql/timestamp_format'

module Sql
  class FieldPredicate
    def self.predicate(value, operator, field)
      self.new(QueryContext.context, value, operator, field).predicate
    end

    def initialize(context, value, operator, field)
      @context = context
      @field = field
      @operator = operator
      @value = value
    end

    def predicate
      [ :field, self.sql_expr, self.sql_value, self.sql_field ]
    end

    def field_def
      @field_def ||= @context.field_def(@field)
    end

    def sql_expr
      "#{sql_field_expr} #{@operator} #{sql_value_placeholder}"
    end

    def sql_field_expr
      @context.dbfield(@field)
    end

    def sql_field
      @sql_field ||= @context.field_def(@field).sql_column_name
    end

    def sql_value_placeholder
      return "to_timestamp(?, '#{timestamp_format}')" if date_field?
      "?"
    end

    def sql_value
      return like_escape(@value) if @operator =~ /LIKE/
      @value
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
