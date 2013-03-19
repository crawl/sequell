require 'sql/type'
require 'sql/date'
require 'sql/config'
require 'sql/type_predicates'

module Sql
  class Column
    include TypePredicates

    attr_reader :decorated_name, :ordered_column_alias

    def initialize(config, decorated_name, alias_map)
      @config = config
      @decorated_name = decorated_name
      @ordered_column_alias =
        alias_map && alias_map['ordered'] && alias_map['ordered'][self.name]
    end

    def to_s
      self.name
    end

    def name
      @name ||= strip_decoration(@decorated_name)
    end

    def sql_column_name
      @sql_column_name ||= @config.sql_field_name_map[self.name] || self.name
    end

    def type
      @type ||= Type.type(@decorated_name)
    end

    # Foreign key into a table.
    def reference?
      @decorated_name =~ /\^/
    end

    def multivalue?
      @decorated_name =~ /\+/
    end

    def lookup_table
      self.reference? && @config.lookup_table(self)
    end

    def lookup_config
      @lookup_config ||= find_lookup_config
    end

    def lookup_field_name
      return @name unless self.reference?
      lookup_config.lookup_field(self.name)
    end

    def fk_name
      return @name unless self.reference?
      lookup_config.fk_field(self.name)
    end

    def unique?
      !self.summarisable?
    end

    def summarisable?
      @decorated_name !~ /\*/
    end

    def value(raw_value)
      self.type.log_value(raw_value)
    end

  private
    def find_lookup_config
      @config.lookup_table_config(self.lookup_table.name)
    end

    def strip_decoration(name)
      name.sub(/[A-Z]*[\W]*$/, '')
    end
  end
end
