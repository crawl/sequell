require 'sql/join'
require 'sql/query_table'
require 'sql/field'

module Sql
  class FieldResolver
    def self.resolve(context, table_set, field)
      return unless field
      self.new(context, table_set, field).resolve
    end

    def initialize(context, table_set, field)
      @context = context
      @tables = table_set
      @field = field
    end

    def resolve
      @field.each_field { |field|
        resolve_field(field)
      }
      @field
    end

    def resolve_field(field)
      # Example predicate place=Snake:3
      # field: 'place'
      # reference field: 'place_id'
      # reference table: 'l_place'
      return field if field.qualified?

      column = field.column
      raise "Unknown field: #{field}" unless column

      # If this is not a local field, we need to join to the alt table first:
      if !@context.local_field_def(field)
        apply_alt_join(@context)
      end

      return resolve_simple_field(field) unless field.reference?

      # Reference column -- find the reference table
      reference_table = column.lookup_table

      # Find the table that the predicate's field belongs to
      qualified_field = field.context_qualified

      # Set up the join
      join = Sql::Join.new(qualified_field.table,
                           reference_table,
                           qualified_field.resolve(column.fk_name))

      # Register the join
      @tables.join(join)

      # And qualify the field with the reference table. NOTE: the
      # reference table *instance* will be bound to an alias specific
      # to the join, so the same table may be joined multiple times
      # with different instances and aliases. Two tables with the same
      # name may be part of different joins and have different
      # aliases. See QueryTable.
      field.table = reference_table
      field.name  = column.lookup_field_name

      field
    end

    def apply_alt_join(context)
      alt = context.alt
      return unless alt
      ref_field = context.join_field
      @tables.join(Join.new(@tables.primary_table, alt.table,
                            ref_field, ref_field))
    end

    def resolve_simple_field(field)
      table = Sql::QueryTable.table(@context.field_table(field))
      field.table = @tables.lookup!(table)
      field
    end
  end
end
