require 'sql/table_context'

module Sql
  # A single table referenced in a query.
  class QueryTable
    include TableContext

    def self.table(thing)
      return thing.query_table if thing.respond_to?(:query_table)
      return thing if thing.is_a?(Sql::TableContext)
      self.new(thing)
    end

    attr_accessor :name, :expr, :alias

    def initialize(name)
      unless name
        require 'pry'
        binding.pry
      end
      @name = name
      @alias = name
    end

    def bind_table_field(field)
      # Nothing to do
    end

    def sql_values
      []
    end

    def dup
      copy = QueryTable.new(@name)
      copy.alias = self.alias
      copy
    end

    def column_list
      @column_list ||=
        Sql::ColumnList.new(SQL_CONFIG,
                            SQL_CONFIG["#{@name}-fields-with-type"],
                            SQL_CONFIG.column_substitutes)
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
      return false unless other
      self.name == other.name && self.alias == other.alias
    end

    def eql?(other)
      self == other
    end

    def hash
      to_s.hash
    end

    def to_sql
      return @name.dup if @alias == @name
      "#{@name} AS #{@alias}"
    end

    def to_s
      if @alias
        "#{@alias}:#{@name}"
      else
        @name
      end
    end

    def inspect
      "QueryTable[#{to_s}]"
    end
  end
end
