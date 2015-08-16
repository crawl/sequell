module Sql
  ##
  # A set of tables and table aliases. Tables may be repeated with different
  # aliases. A table may be a QueryTable instance, or a QueryAST.
  class TableSet
    def self.next_id
      @@id ||= 0
      @@id += 1
    end

    attr_reader :id

    include Enumerable

    def initialize
      @table_aliases = { }
      @tables = []
      @alias_index = 0
      @id = self.class.next_id
    end

    def each(&block)
      @tables.each(&block)
    end

    def size
      @tables.size
    end

    ##
    # Replaces old_table with new_table in this table list.
    def rebind(old_table, new_table)
      @tables = @tables.map { |t| t == old_table ? new_table : t }

      if old_table.alias != new_table.alias
        raise("Cannot rebind #{old_table} -> #{new_table}: alias mismatch")
      end
      @table_aliases[old_table.alias] = new_table if @table_aliases[old_table.alias]
    end

    def table(table_name)
      @tables.find { |t| t.name == table_name }
    end

    ##
    # Finds the table with the current table's alias in this table set. If the
    # table alias is not found, registers the table with its current alias and
    # returns the table.
    def lookup!(table)
      found_table = self[table.alias]
      unless found_table
        return register_table(table)
      end
      found_table
    end

    def [](table_alias)
      table_alias = table_alias.alias if table_alias.respond_to?(:alias)
      @table_aliases[table_alias]
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

    private

    def record_table(table)
      @tables << table unless known_table?(table)
    end

    def disambiguate_alias(table_alias)
      while true
        @alias_index += 1
        new_alias = "#{table_alias}_#{@alias_index}"
        return new_alias unless self[new_alias]
      end
    end

    def known_table?(table)
      @tables.index(table)
    end

  end
end
