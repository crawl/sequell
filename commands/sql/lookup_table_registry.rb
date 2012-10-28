require 'sql/query_table'

module Sql
  class LookupTableRegistry
    def initialize(cfg)
      @cfg = cfg
      @lookups = @cfg['lookup-tables']
    end

    def lookup_table_config(lookup_table_name)
      cfg = @lookups[lookup_table_name]
      return nil unless cfg
      Sql::LookupTableConfig.new(cfg)
    end

    def lookup_table(column)
      key = lookup_key(column)
      return Sql::QueryTable.new("l_#{key}")
    end

    def lookup_key(column)
      @column_key[column.name] ||= find_lookup_key(column)
    end

  private
    def find_lookup_key(column)
      for key, value in @lookups
        if lookup_matches?(value, column)
          return key
        end
      end
      column.name
    end

    def lookup_matches?(lookup, column)
      if lookup.is_a?(Array)
        return lookup.include?(column.name)
      else
        if lookup['fields'] && lookup['fields'].include?(column.name)
          return true
        end

        return lookup['generated-fields'] &&
          lookup['generated-fields'].map { |f|
            Sql::Column.new(f)
          }.find { |c| c.name == column.name }
      end
    end
  end
end
