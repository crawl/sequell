require 'sql/type_predicates'

module Sql
  module FieldPredicates
    include TypePredicates

    def inspect
      to_s
    end

    def type
      field.type
    end

    def resolve(new_field_name)
      clone = self.dup
      clone.field = self.field.resolve(new_field_name)
      clone
    end

    def display_format
      field.display_format
    end

    def name
      field.name
    end

    def table
      field.table
    end

    def table=(new_table)
      field.table = new_table
    end

    def qualified?
      field.qualified?
    end

    def prefixed?
      field.prefixed?
    end

    def has_prefix?(prefix)
      field.has_prefix?(prefix)
    end

    def reference?
      field.reference?
    end

    def context
      Sql::QueryContext.context
    end

    def value_key?
      field.value_key?
    end

    def sort?
      field.sort?
    end

    def max?
      field.max?
    end

    def each_field(&block)
      field.each_field(&block) if self.field
    end

    def unique_valued?
      field.unique_valued?
    end

    def local?
      field.local?
    end

    def summarisable?
      field.summarisable?
    end

    def column
      field.column
    end

    def known?
      value_key? || column
    end

    def === (thing)
      @field === thing
    end
  end
end
