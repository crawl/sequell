require 'sql/query_table'
require 'set'

module Sql
  # Tracks the set of tables referenced in a query with one primary table
  # and any number of additional join tables.
  class QueryTables
    attr_reader :primary_table, :tables

    def initialize(primary_table)
      @primary_table = Sql::QueryTable.table(primary_table)
      @table_aliases = { @primary_table.alias => @primary_table }
      @tables = [@primary_table]
      @joins = []
      @alias_index = 0
    end

    def dup
      tables = self.class.new(@primary_table.dup)
      tables.instance_variable_set(:@joins, @joins.map { |j| j.dup })
      tables.instance_variable_set(:@tables, @tables.map { |t| t.dup })
      tables.instance_variable_set(:@table_aliases, @table_aliases.dup)
      tables
    end

    def resolve!(table, force_new_alias=false)
      return table if !force_new_alias && self[table.alias] == table

      # Is this table's alias already taken? Give it a new one if so
      new_alias = table.alias
      if self[new_alias]
        new_alias = disambiguate_alias(table.alias)
        table.alias = new_alias
      end
      register_table(table)
      @table_aliases[new_alias] = table
    end

    def [](table_alias)
      table_alias = table_alias.alias if table_alias.respond_to?(:alias)
      @table_aliases[table_alias]
    end

    def table(table_name)
      @tables.find { |t| t.name == table_name }
    end

    def join(join_condition)
      unless join_clause_matches?(join_condition)
        raise "The join condition: #{join_condition} does not match the existing tables in #{self}"
      end

      if @joins.include?(join_condition)
        update_join_table_aliases(join_condition)
        return
      end

      self.resolve!(join_condition.left_table)
      self.resolve!(join_condition.right_table, :force_new_alias)

      @joins << join_condition
      self
    end

    # Returns the table name and joins, suitable for the FROM clause
    # of a query.
    def to_sql
      sql = @primary_table.to_sql
      for join in @joins
        sql << " " << join.to_sql
      end
      sql
    end

    def to_s
      "QueryTables[#{@tables.map(&:name).join(',')}]"
    end

  private
    def join_clause_matches?(join)
      known_table?(join.left_table)
    end

    def register_table(table)
      @tables << table unless known_table?(table)
    end

    def known_table?(table)
      @tables.index(table)
    end

    def update_join_table_aliases(join)
      existing_join = @joins.find { |j| j == join }
      join.left_table.alias = existing_join.left_table.alias
      join.right_table.alias = existing_join.right_table.alias
    end

    def disambiguate_alias(table_alias)
      @alias_index += 1
      "#{table_alias}_#{@alias_index}"
    end
  end
end
