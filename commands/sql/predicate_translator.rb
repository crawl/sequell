module Sql
  class PredicateTranslator
    def self.translate(context, tables, predicate)
      self.new(context, tables, predicate).translate
    end

    attr_reader :context, :tables, :predicate

    def initialize(context, tables, predicate)
      @context = context
      @tables = tables
      @predicate = predicate
      @field = predicate.field
    end

    def translate
      return if predicate.resolved?

      # Is this a test for the milestone having no associated game?
      if @field === 'ktyp' && @predicate.value.empty? &&
          @predicate.operator.equal? && !@context.local_field_def(@field)
        apply_orphan_milestone_join
      end
    end

  private
    def apply_orphan_milestone_join
      return unless context.alt
      ref_field = context.join_field
      alt_table = Sql::QueryTable.table(context.alt.table)

      join = Join.new(@tables.primary_table, alt_table, ref_field, ref_field)
      join.left_join = true
      @tables.join(join)

      @field.table = alt_table
      @field.name  = context.join_field
      @predicate.value_expr = 'NULL'
      @predicate.operator = Sql::Operator.op('IS')
      @predicate.static = true
    end
  end
end
