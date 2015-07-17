module Sql
  ##
  # Translates query predicates into join conditions.
  class PredicateTranslator
    def self.translate(ast, predicate)
      return if predicate.resolved?
      self.new(ast, predicate).translate
    end

    attr_reader :ast, :predicate

    def initialize(ast, predicate)
      @predicate = predicate
      @ast = ast
      @field = predicate.field
    end

    def context
      @context ||= ast.context
    end

    def tables
      @tables ||= ast.query_tables
    end

    def translate
      return if predicate.resolved?

      # Is this a test for the milestone having no associated game?
      if @field === 'ktyp' && @predicate.value.empty? &&
          @predicate.operator.equal? && !context.local_field_def(@field)
        apply_orphan_milestone_join
      end
    end

  private

    def apply_orphan_milestone_join
      return unless context.alt
      ref_field = context.join_field
      alt_table = Sql::QueryTable.table(context.alt.table)

      join = Join.new(tables.primary_table, alt_table, ref_field, ref_field)
      join.left_join = true
      @tables.join(join)

      @field.table = alt_table
      @field.name  = context.join_field
      @predicate.value = nil
      @predicate.operator = :is
    end
  end
end
