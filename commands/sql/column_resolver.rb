require 'sql/field_resolver'

module Sql
  class ColumnResolver
    # Walks a tree of predicates and resolves reference fields in the
    # predicates to their respective join tables.
    def self.resolve(context, query_tables, predicates)
      self.new(context, query_tables, predicates).resolve
    end

    def initialize(context, query_tables, predicates)
      @context = context
      @tables = query_tables
      @predicates = predicates
    end

    def resolve
      @predicates.each_predicate { |p|
        resolve_predicate(p)
      }
    end

    def resolve_predicate(p)
      Sql::FieldResolver.resolve(@context, @tables, p.field)
    end
  end
end
