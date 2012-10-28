module Sql
  class Field
    def self.field(name)
      return nil unless name
      return name if name.is_a?(self)
      self.new(name)
    end

    attr_reader :prefix, :aliased_name
    attr_accessor :table
    attr_accessor :name

    # A (possibly-prefixed) field
    def initialize(field_name)
      @full_name = field_name
      @aliased_name = field_name.downcase
      @prefix = nil
      @table = nil
      if @aliased_name =~ /^(\w+):([\w.]+)$/
        @prefix, @aliased_name = $1, $2
      end
      @name = SQL_CONFIG.column_aliases[@aliased_name] || @aliased_name
    end

    def sql_column_name
      SQL_CONFIG.sql_field_name_map[self.name] || self.name
    end

    def assert_valid!
      self.field_def or raise "Unknown field name: #{self}"
    end

    def resolve(new_name)
      new_name = new_name.name if new_name.is_a?(self.class)
      self.class.new(@prefix ? "#{@prefix}:#{new_name}" : new_name)
    end

    def reference_field
      self.resolve(self.sql_column_name + '_id')
    end

    def === (name)
      if name.is_a?(Enumerable)
        name.any? { |n| @name == n }
      else
        @name == name
      end
    end

    def sort?
      max? or min?
    end

    def max?
      @name == 'max'
    end

    def min?
      @name == 'min'
    end

    def prefixed?
      @prefix
    end

    def has_prefix?(prefix)
      @prefix == prefix
    end

    def to_s
      @full_name
    end
  end
end
