require 'sql/query_table'
require 'sql/lookup_table_config'

module Sql
  class LookupTableRegistry
    def initialize(cfg)
      @cfg = cfg
      @lookup_configs = cfg['lookup-tables']
      @column_keys = { }
    end

    def lookup_table_config(lookup_table_name)
      name = lookup_table_name.sub(/^l_/, '')
      @lookups[name] || Sql::LookupTableConfig.new(@cfg, name, nil)
    end

    def lookup_table(column)
      key = lookup_key(column)
      return Sql::QueryTable.new("l_#{key}")
    end

    def lookup_key(column)
      @column_keys[column.name] ||= find_lookup_key(column)
    end

    def lookups
      @lookups ||= parse_lookup_configs(@lookup_configs)
    end

  private
    def parse_lookup_configs(configs)
      lookups = { }
      for name, lookup_cfg in configs
        lookups[name] = Sql::LookupTableConfig.new(@cfg, name, lookup_cfg)
      end
      lookups
    end

    def find_lookup_key(column)
      for key, lookup in lookups
        return key if lookup.match?(column)
      end
      column.name
    end
  end
end
