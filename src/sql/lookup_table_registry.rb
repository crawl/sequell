require 'sql/query_table'
require 'sql/lookup_table_config'

module Sql
  class LookupTableRegistry
    def initialize(cfg)
      @cfg = cfg
      @lookups = @cfg['lookup-tables']
      @column_keys = { }
    end

    def lookup_table_config(lookup_table_name)
      lookup_table_name = lookup_table_name.sub(/^l_/, '')
      lookup_cfg = @lookups[lookup_table_name]
      Sql::LookupTableConfig.new(@cfg, lookup_table_name, lookup_cfg)
    end

    def lookup_table(column)
      key = lookup_key(column)
      return Sql::QueryTable.new("l_#{key}")
    end

    def lookup_key(column)
      @column_keys[column.name] ||= find_lookup_key(column)
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
            Sql::Column.new(@cfg, f, {})
          }.find { |c| c.name == column.name }
      end
    end
  end
end
