require 'sql/query_context'
require 'sql/query_table'
require 'sql/type_predicates'

module Sql
  class Field
    def self.field(name)
      return nil unless name
      return name if self.field?(name)
      self.new(name)
    end

    def self.field?(name)
      name.is_a?(self)
    end

    include TypePredicates

    attr_reader :prefix, :aliased_name, :full_name
    attr_accessor :table
    attr_accessor :name

    # A (possibly-prefixed) field
    def initialize(field_name)
      @full_name = field_name.downcase
      @aliased_name = field_name.downcase
      @prefix = nil
      @table = nil
      if @aliased_name =~ /^(\w+):([\w.]+)$/
        @prefix, @aliased_name = $1, $2
      end
      @name = SQL_CONFIG.column_aliases[@aliased_name] || @aliased_name
      @oname = @name.dup
    end

    def context
      Sql::QueryContext.context
    end

    # Returns a copy of this field that is qualified with the table of
    # the context.
    def context_qualified
      context.table_qualified(self)
    end

    def column_prop(prop)
      self.column && self.column.send(prop)
    end

    def unique_valued?
      column_prop(:unique?)
    end

    def value_key?
      context.value_key?(self.name)
    end

    def local?
      context.local_field_def(self)
    end

    def summarisable?
      return true if self.value_key?
      column_prop(:summarisable?)
    end

    def reference?
      column_prop(:reference?)
    end

    def type
      column_prop(:type) || ''
    end

    def column
      @column ||= context.field_def(self)
    end

    def expr?
      false
    end

    def each_field
      yield self
    end

    def dup
      copy = Field.new(@full_name.dup)
      copy.table = @table.dup if @table
      copy.name = self.name.dup
      copy
    end

    def qualified?
      @table
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

    def to_sql
      unless @table
        raise "Attempt to use unresolved field #{self} in a SQL statement"
      end
      "#{table.alias}.#{self.sql_column_name}"
    end

    def to_s
      return "#{@table}.#{@name}" if @table
      @name
    end
  end
end
