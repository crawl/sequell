module Sql
  class AggregateExpression
    def self.aggregate_sql(table_set, expr)
      return expr.to_sql unless expr.first && expr.arity == 1
      self.new(table_set, expr).to_sql
    end

    attr_reader :table_set, :expr, :column

    def initialize(table_set, expr)
      @table_set = table_set
      @expr = expr.meta? ? expr.first : expr
    end

    def to_sql
      return version_maxmin_sql if version_column? && max_min_expr?
      @expr.to_sql
    end

    def version_column?
      expr.kind == :funcall && expr.first.kind == :field &&
        expr.arity == 1 && expr.first === ['v', 'cv']
    end

    def max_min_expr?
      expr.kind == :funcall && (expr.name == 'max' || expr.name == 'min')
    end

  private
    def version_maxmin_sql
      field = @expr.first
      original_sql_field_name = field.sql_column_name
      reference_table = Sql::QueryTable.table(field.column.lookup_table)
      @table_set.resolve!(reference_table, true)
      field.name = field.name + 'num'
      key_field_sql = @expr.to_sql
      sql = ("(SELECT #{original_sql_field_name} " +
        "FROM #{reference_table.to_sql} WHERE " +
        "#{reference_table.field_sql(field)} = #{key_field_sql})")
      sql
    end
  end
end
