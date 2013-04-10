require 'sql/type'
require 'sql/query_context'
require 'sql/query_table'
require 'sql/field_predicates'
require 'query/ast/term'

module Sql
  class Field < Query::AST::Term
    def self.field(name)
      return nil unless name
      return name if name.is_a?(self)
      self.new(name)
    end

    def self.field?(name)
      name.is_a?(self)
    end

    include FieldPredicates

    attr_reader :prefix, :aliased_name, :full_name, :canonical_name
    attr_accessor :table
    attr_accessor :name

    @@aliased_name_cache = { }

    # A (possibly-prefixed) field
    def initialize(field_name)
      @full_name = field_name.downcase
      @aliased_name = @full_name
      @prefix = nil
      @table = nil
      @prefix, @aliased_name = split_aliased_name(@aliased_name)
      @name = SQL_CONFIG.column_aliases[@aliased_name] || @aliased_name
      @canonical_name = @name
    end

    def split_aliased_name(aliased_name)
      @@aliased_name_cache[aliased_name] ||= split_prefixed_name(aliased_name)
    end

    def fields
      [self]
    end

    def kind
      :field
    end

    def context
      Sql::QueryContext.context
    end

    # Returns a copy of this field that is qualified with the table of
    # the context.
    def context_qualified
      context.table_qualified(self)
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
      column_prop(:type) || Type.type('')
    end

    def column
      @column ||= context.field_def(self)
    end

    def expr?
      false
    end

    def simple_field?
      true
    end

    def each_field
      yield self
    end

    def comparison_value(raw_value)
      self.type.comparison_value(raw_value)
    end

    def version_number?
      return @version_number if @version_number_checked
      @version_number_checked = true
      @version_number = self === ['v', 'cv']
    end

    def dup
      copy = Field.new(@full_name.dup)
      copy.table = @table.dup if @table
      copy.name = self.name.dup
      copy
    end

    def display_format
      nil
    end

    def qualified?
      @table
    end

    alias :resolved? :qualified?

    def sql_column_name
      SQL_CONFIG.sql_field_name_map[self.name] || self.name
    end

    def assert_valid!
      self.field_def or raise "Unknown field: #{self}"
    end

    def resolve(new_name)
      new_name = new_name.name if new_name.is_a?(self.class)
      self.class.new(@prefix ? "#{@prefix}:#{new_name}" : new_name)
    end

    def reference_field
      self.resolve(self.sql_column_name + '_id')
    end

    def bind_ordered_column!
      if self.column && self.column.ordered_column_alias
        self.name = self.column.ordered_column_alias
      end
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

    def to_query_string(paren=false)
      prefixed_name
    end

    def prefixed_name
      @prefix ? "#{@prefix}:#{@name}" : to_s
    end

    def to_sql
      unless @table
        raise "Attempt to use unresolved field #{self} in a SQL statement"
      end
      sql_typecast("#{table.alias}.#{self.sql_column_name}")
    end

    def sql_typecast(expr)
      self.type.comparable_expr(expr)
    end

    def to_s
      @name
    end

  private
    def split_prefixed_name(name)
      if name =~ /^(\w+):([\w.]+)$/
        [$1, $2]
      else
        [nil, name]
      end
    end
  end
end
