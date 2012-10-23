require 'sql/timestamp_format'

module Sql
  class FieldPredicate
    def self.predicate(value, operator, field_name, field_expr=nil)
      self.new(QueryContext.context, value, operator, field_name,
               field_expr=nil).predicate
    end

    def initialize(context, value, operator, field_name, field_expr=nil)
      @context = context
      @field_expr = @context.dbfield(field_expr || field_name)
      @field_name = field_name
      @sql_field_name = @field_name
      @sql_field_name = $1 + @field_name if @field_expr =~ /^(\w+\.)/
      @operator = operator
      @value = value
    end

    def predicate
      [ :field, self.sql_expr, self.sql_value, self.sql_field ]
    end

    def sql_expr
      "#{sql_field_expr} #{@operator} #{sql_value_placeholder}"
    end

    def sql_field_expr
      @field_expr || sql_field
    end

    def sql_field
      @sql_field_name
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
      @context.field_type(@field_name) == 'D'
    end

    def timestamp_format
      TimestampFormat.format_string(@value)
    end
  end
end
