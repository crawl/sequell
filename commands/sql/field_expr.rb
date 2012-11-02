require 'sql/field'
require 'sql/field_predicates'

module Sql
  # A SQL expression for a given field's db column.
  class FieldExpr
    def self.expr(field)
      return field if field.respond_to?(:expr?) && field.expr?
      self.new(field)
    end

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

    def self.autocase(field)
      field = Sql::Field.field(field)
      if field.case_sensitive?
        self.lower(field)
      else
        self.new(field)
      end
    end

    attr_reader :expr
    attr_accessor :field, :type

    include FieldPredicates

    def initialize(field, expression=nil, type=nil)
      @field = Sql::Field.field(field)
      @expr  = expression
      @type  = type
    end

    def type
      @type ||= @field.type
    end

    def expr?
      true
    end

    def dup
      copy = FieldExpr.new(@field.dup)
      copy.instance_variable_set(:@expr, @expr.dup) if @expr
      copy.instance_variable_set(:@type, @type.dup) if @type
      copy
    end

    def sql_expr
      return @expr unless @field
      sql_field_name = @field.to_sql if @field
      @expr ? build_expr(@expr, sql_field_name) : sql_field_name
    end

    def to_sql
      sql_expr
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
