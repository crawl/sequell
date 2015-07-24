require 'sql/query_table'
require 'set'

module Sql
  # Tracks the set of tables referenced in a query with one primary table
  # and any number of additional join tables.
  class QueryTables
    attr_reader :primary_table, :tables, :joins

    def self.next_id
      @@id ||= 0
      @@id += 1
    end

    def initialize(query_ast, primary_table)
      @id = self.class.next_id
      @query_ast = query_ast
      @primary_table = Sql::QueryTable.table(primary_table)
      @table_aliases = { }
      @tables = []
      @joins = []
      @alias_index = 0
    end

    def initialize_copy(other)
      super
      @id = self.class.next_id
      @table_aliases = @table_aliases.dup
      @tables = @tables.dup
      @joins = @joins.dup
    end

    def lookup!(table)
      return lookup!(primary_table) if table.equal?(@query_ast)

      found_table = self[table.alias]
      unless found_table
        return register_table(table)
      end
      found_table
    end

    def find_join(join_condition)
      @joins.find { |j|
        j.tables_match?(join_condition)
      }
    end

    def register_table(table, force_new_alias=false)
      return table if !force_new_alias && self[table.alias] == table

      # Is this table's alias already taken? Give it a new one if so
      new_alias = table.alias
      if self[new_alias]
        new_alias = disambiguate_alias(table.alias)
        table.alias = new_alias
      end
      record_table(table)
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
      join_with(join_condition) { |joins|
        STDERR.puts("#{self} Appending join condition: #{join_condition}")
        joins << join_condition
      }
    end

    ##
    # Returns the table name and joins, suitable for the FROM clause
    # of a query.
    def to_sql
      sort_join_conditions!
      sql_frags = []
      if !@joins.empty?
        include_left_table = true
        seen_tables = Set.new
        for join in @joins
          if !include_left_table && !seen_tables.include?(join.left_table)
            if seen_tables.include?(join.right_table)
              join.flip!
            else
              require 'pry'
              binding.pry
              raise("Bad join condition: #{join}: references table that's not in the list of priors: #{seen_tables.to_a.map(&:to_s)}")
            end
          end

          sql_frags << join.to_sql(include_left_table)

          seen_tables << join.left_table if include_left_table
          seen_tables << join.right_table
          include_left_table = false
        end
      else
        sql_frags = primary_table.to_sql
      end
      sql_frags.join("\n ")
    end

    ##
    # Returns any SQL ? placeholder values from JOINed subqueries.
    def values
      values = []
      include_left_table = true
      @joins.each { |j|
        values += j.values(include_left_table)
        include_left_table = false
      }
      values
    end

    def to_s
      "QueryTables[##{@id} #{@tables.map(&:name).join(',')}]"
    end

    private

    # Reorder join conditions so that each join refers to one of the tables in
    # one of the prior joins.
    def sort_join_conditions!
      seen_tables = Set.new
      unsorted_joins = @joins.dup
      sorted_joins = [unsorted_joins.shift]
      seen_tables << sorted_joins.first.left_table
      seen_tables << sorted_joins.first.right_table
      until unsorted_joins.empty?
        next_join_condition = find_next_join_condition(seen_tables, unsorted_joins)
        unless next_join_condition
          raise("Bad join condition chain: no condition in #{unsorted_joins} matches the table set #{seen_tables.to_a.map(&:to_s)}")
        end
        sorted_joins << next_join_condition
        seen_tables << next_join_condition.left_table
        seen_tables << next_join_condition.right_table
      end
      @joins = sorted_joins
    end

    def find_next_join_condition(table_set, join_list)
      found_join_condition = join_list.find { |j|
        table_set.include?(j.left_table) || table_set.include?(j.right_table)
      }
      return nil unless found_join_condition

      join_list.delete(found_join_condition)
      unless table_set.include?(found_join_condition.left_table)
        found_join_condition.flip!
      end
      found_join_condition
    end

    def join_with(join_condition)
      if @joins.include?(join_condition)
        update_join_table_aliases(join_condition)
        return
      end

      register_table(join_condition.left_table)
      register_table(join_condition.right_table, :force_new_alias)

      yield @joins

      self
    end

    def record_table(table)
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
      while true
        @alias_index += 1
        new_alias = "#{table_alias}_#{@alias_index}"
        return new_alias unless self[new_alias]
      end
    end
  end
end
