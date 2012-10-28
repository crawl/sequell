module Sql
  # A single table referenced in a query.
  class QueryTable
    def self.table(thing)
      return thing if thing.is_a?(self)
      self.new(thing)
    end

    attr_accessor :name, :alias

    def initialize(name)
      @name = name
      @alias = name
    end

    def column_list
      @column_list ||=
        Sql::ColumnList.new(SQL_CONFIG,
                            SQL_CONFIG["#{@name}-fields-with-type"])
    end

    def generated_columns
      self.lookup_table ? self.lookup_table.generated_columns : []
    end

    def lookup_table
      SQL_CONFIG.lookup_table_config(self.name)
    end

    def field_sql_name(field)
      column = self.column_list[field.name]
      column ? column.sql_column_name : field.sql_column_name
    end

    def field_sql(field)
      "#{@alias}.#{field_sql_name(field)}"
    end

    def == (other)
      self.name == other.name && self.alias == other.alias
    end

    def to_sql
      return @name.dup if @alias == @name
      "#{@name} AS #{@alias}"
    end

    def to_s
      @name
    end
  end
end
