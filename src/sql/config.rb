require 'sql/column_list'
require 'sql/lookup_table_registry'
require 'sql/function_defs'
require 'sql/field_value_transformer'
require 'crawl/milestone_type'

module Sql
  class Config
    attr_reader :cfg

    def initialize(cfg)
      @cfg = cfg
    end

    def functions
      @functions ||= Sql::FunctionDefs.new(@cfg['value-functions'])
    end

    def aggregate_functions
      @aggregate_functions ||= Sql::FunctionDefs.new(@cfg['aggregate-functions'])
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
      @milestone_types ||= Crawl::MilestoneType
    end

    def sql_field_name_map
      @sql_field_name_map ||= @cfg['sql-field-names']
    end

    def column_aliases
      @cfg['column-aliases']
    end

    def column_substitutes
      @cfg['column-substitutes']
    end

    def field_value_transformer
      @field_value_transformer ||=
        Sql::FieldValueTransformer.new(self['field-transforms'])
    end

    def transform_value(value, field)
      field_value_transformer.transform(value, field)
    end

    def logfields
      @logfields ||=
        Sql::ColumnList.new(self,
                            @cfg['logrecord-fields-with-type'],
                            self.column_substitutes)
    end

    def milefields
      @milefields ||=
        Sql::ColumnList.new(self, @cfg['milestone-fields-with-type'],
                            self.column_substitutes)
    end

    def fakefields
      @fakefields ||=
        Sql::ColumnList.new(self, @cfg['fake-fields-with-type'],
                            self.column_substitutes)
    end

    def [](name)
      @cfg[name.to_s]
    end
  end
end
