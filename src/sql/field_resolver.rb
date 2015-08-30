require 'sql/join'
require 'sql/query_table'
require 'sql/field'

module Sql
  ##
  # Resolves Sql::Fields in the given AST, binding them to the tables they're
  # from. Automatically joins the base context table to the autojoin table for
  # fields that belong to the autojoin table. Automatically joins lookup tables
  # to the main table for lookup (reference) fields.
  class FieldResolver
    def self.resolve(ast, field)
      return unless field
      self.new(ast, field).resolve
    end

    attr_reader :ast
    def initialize(ast, field)
      @ast = ast
      @field = field.is_a?(String) ? Sql::Field.field(field) : field
    end

    def context
      @ast.context
    end

    def tables
      @tables ||= @ast.query_tables
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
      unless column
        require 'pry'
        binding.pry
        raise("Unknown field: #{field} (#{field.context})")
      end

      column.bind_table_field(field)

      # If this is not a local field, we need to join to the alt table first:
      if column.table != field.context && field.context.autojoin?(column.table)
        apply_alt_join(field)
      end

      # Don't try to join lookup if this is a reference to an outer query field:
      if outer_query_reference?(field, column)
        # Create a proxy field to resolve on the outer query:
        field_proxy = field.unqualified
        field_proxy.context = column.table
        field_proxy = Sql::FieldResolver.resolve(column.table, field_proxy)
        field.table = field_proxy.table
        field.sql_name = field_proxy.sql_name
        return field
      end

      return resolve_simple_field(field) if !field.reference? || field.reference_id_only?

      # Reference column -- find the reference table
      reference_table = column.lookup_table

      # Find the table that the predicate's field belongs to
      qualified_field = field.context_qualified

      # Set up the join
      right_field = Sql::Field.field('id')
      right_field.table = reference_table
      join = Sql::Join.new(qualified_field.table,
                           reference_table,
                           [qualified_field.resolve(column.fk_name)],
                           :inner,
                           [right_field])

      # Register the join
      tables.join(join)

      # And qualify the field with the reference table. NOTE: the
      # reference table *instance* will be bound to an alias specific
      # to the join, so the same table may be joined multiple times
      # with different instances and aliases. Two tables with the same
      # name may be part of different joins and have different
      # aliases. See QueryTable.
      field.table = reference_table
      field.sql_name = column.lookup_field_name

      field
    end

  private

    def outer_query_reference?(field, column)
      column.table.equal?(field.context.outer_query)
    end

    def apply_alt_join(field)
      alt = field.context.alt
      return unless alt
      ref_field = context.join_field
      tables.join(Join.new(tables.primary_table, alt.table,
                           ref_field, ref_field))
    end

    def resolve_simple_field(field)
      #col = field.column
      col = ast.resolve_column(field, :internal_expr)
      table = col.table
      field.table = tables.lookup!(table)
      field.sql_name = field.column.fk_name.to_s if field.reference_id_only?
      field
    end
  end
end
