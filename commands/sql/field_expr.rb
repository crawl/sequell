require 'sql/field'

module Sql
  # A SQL expression for a given field's db column.
  class FieldExpr
    def self.max(field)
      self.new(field, 'MAX')
    end

    def self.min(field)
      self.new(field, 'MIN')
    end

    def self.count_distinct(field)
      self.new(field, 'COUNT(DISTINCT %s)')
    end

    def self.sum(field)
      self.new(field, 'SUM')
    end

    def self.count_all(col_alias=nil)
      count = "COUNT(*)"
      count << " AS #{col_alias}" if col_alias
      self.new(nil, count)
    end

    def self.lower(field)
      self.new(field, 'CAST(%s AS CITEXT)')
    end

    def self.autocase(field, context)
      if context.case_sensitive?(field)
        self.lower(field)
      else
        self.new(field)
      end
    end

    attr_reader :field, :expr

    def initialize(field, expression=nil)
      @field = Sql::Field.field(field)
      @expr  = expression
    end

    def dup
      copy = self.new(@field.dup)
      copy.instance_variable_set(:@expr, @expr.dup)
      copy
    end

    def sql_expr(table_set, context)
      return @expr unless @field
      sql_field_name = self.sql_field(table_set, context) if @field
      @expr ? build_expr(@expr, sql_field_name) : sql_field_name
    end

    def sql_field(table_set, context)
      context.dbfield(@field, table_set)
    end

    def to_sql(table_set, context)
      sql_expr(table_set, context)
    end

    def == (other)
      @field.name == other.field.name &&
        @field.prefix == other.field.prefix &&
        @expr == other.expr
    end

    def to_s
      return @field.to_s unless @expr
      build_expr(@expr, @field.to_s)
    end

  private
    def build_expr(expr, field)
      return expr.sub('%s', field) if expr =~ /%s/
      "#{expr}(#{field})"
    end
  end
end
