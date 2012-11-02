require 'sql/date'
require 'sql/config'
require 'sql/type_predicates'

module Sql
  class Column
    include TypePredicates

    def initialize(config, decorated_name)
      @config = config
      @decorated_name = decorated_name
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
      @type ||= find_type(@decorated_name)
    end

    # Foreign key into a table.
    def reference?
      @decorated_name =~ /\^/
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
      case
      when self.numeric?
        raw_value.to_i
      when self.date?
        Sql::Date.log_date(raw_value)
      else
        raw_value
      end
    end

  private
    def find_lookup_config
      @config.lookup_table_config(self.lookup_table.name)
    end

    def strip_decoration(name)
      name.sub(/[A-Z]*[\W]*$/, '')
    end

    def find_type(name)
      raw_type = find_raw_type(name)
      case raw_type
      when 'PK'
        'I'
      when /^I/
        'I'
      else
        raw_type
      end
    end

    def find_raw_type(name)
      if name =~ /([A-Z]+)/
        return $1
      elsif name =~ /!/
        return '!'
      end
      ''
    end
  end
end
