require 'sql/type'
require 'sql/date'
require 'sql/config'
require 'sql/type_predicates'

module Sql
  class Column
    include TypePredicates

    ##
    # The name of the column with type and metadata annotations.
    attr_reader :decorated_name

    ##
    # If non-nil, then the alias column MUST be used for ORDER BY and < >
    # comparison operators. This is used to make ordering by versions use the
    # synthetic version number instead of the string version.
    attr_reader :ordered_column_alias

    attr_reader :table, :config

    def initialize(config, decorated_name, alias_map=nil)
      @config = config
      @decorated_name = decorated_name
      @ordered_column_alias =
        alias_map && alias_map['ordered'] && alias_map['ordered'][self.name]
    end

    ##
    # Binds this column to a table definition.
    def bind(table)
      clone = self.dup
      clone.instance_variable_set(:@table, table)
      clone
    end

    ##
    # Binds the given field to the underlying table as in use. This may provoke
    # an additional join on the table for autojoining fields.
    def bind_table_field(field)
      table.bind_table_field(field)
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

    ##
    # The name of the foreign key reference column (the foo_id column).
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

    def inspect
      "#{@table}.#{name}"
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
