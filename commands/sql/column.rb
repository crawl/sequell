require 'sql/date'
require 'sql/config'

module Sql
  class Column
    def initialize(config, decorated_name)
      @config = config
      @decorated_name = decorated_name
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

    def text?
      self.type == 'S'
    end

    def date?
      self.type == 'D'
    end

    def numeric?
      self.type == 'I'
    end

    def boolean?
      self.type == '!'
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
      'S'
    end
  end
end
