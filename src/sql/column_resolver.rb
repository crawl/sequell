require 'sql/field_resolver'
require 'sql/predicate_translator'

module Sql
  class ColumnResolver
    ##
    # Walks a tree of predicates in a query AST and resolves reference fields in
    # the predicates to their respective join tables.
    def self.resolve(ast)
      self.new(ast).resolve
    end

    def initialize(ast)
      @ast = ast
    end

    def resolve
      @ast.each_predicate { |p|
        resolve_predicate(p)
      }
      @ast.each_field { |f|
        Sql::FieldResolver.resolve(@ast.query_tables, f)
      }
    end

    def resolve_predicate(p)
      Sql::PredicateTranslator.translate(@ast, p)
    end
  end
end
