require 'sql/column_list'
require 'sql/lookup_table_registry'
require 'sql/function_defs'

module Sql
  class Config
    attr_reader :cfg

    def initialize(cfg)
      @cfg = cfg
    end

    def functions
      @functions ||= Sql::FunctionDefs.new(@cfg['value-functions'])
    end

    def lookup_table(column)
      self.lookup_table_registry.lookup_table(column)
    end

    def lookup_table_config(lookup_table_name)
      self.lookup_table_registry.lookup_table_config(lookup_table_name)
    end

    def lookup_table_registry
      @lookup_table_registry ||= Sql::LookupTableRegistry.new(self)
    end

    def games
      @games ||= self.game_prefixes.keys
    end

    def game_prefixes
      @game_prefixes ||= @cfg['game-type-prefixes']
    end

    def default_game_type
      @cfg['default-game-type']
    end

    def milestone_types
      @milestone_types ||= @cfg['milestone-types']
    end

    def sql_field_name_map
      @sql_field_name_map ||= @cfg['sql-field-names']
    end

    def column_aliases
      @cfg['column-aliases']
    end

    def aggregate_function_types
      @cfg['aggregate-function-types']
    end

    def logfields
      @logfields ||=
        Sql::ColumnList.new(self, @cfg['logrecord-fields-with-type'])
    end

    def milefields
      @milefields ||=
        Sql::ColumnList.new(self, @cfg['milestone-fields-with-type'])
    end

    def fakefields
      @fakefields ||=
        Sql::ColumnList.new(self, @cfg['fake-fields-with-type'])
    end

    def [](name)
      @cfg[name.to_s]
    end
  end
end
