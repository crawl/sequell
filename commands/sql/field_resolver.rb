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
      # Example predicate place=Snake:3
      # field: 'place'
      # reference field: 'place_id'
      # reference table: 'l_place'
      field = @field
      column = @context.field_def(field)
      return unless column && column.reference?

      # Reference column -- find the reference table
      reference_table = column.lookup_table

      # Find the table that the predicate's field belongs to
      qualified_field = @context.table_qualified(field)

      # Set up the join
      join = Sql::Join.new(qualified_field.table,
                           reference_table,
                           qualified_field.reference_field)

      # Register the join
      @tables.join(join)

      # And qualify the field with the reference table
      field.table = reference_table
    end
  end
end
