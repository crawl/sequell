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
      STDERR.puts("ColumnResolver: #{@ast}")
      @ast.head.each_predicate { |p|
        resolve_predicate(p)
      }
      resolve_individual_fields(@ast.head)
      if @ast.respond_to?(:join_conditions)
        @ast.join_conditions.each { |jc|
          resolve_individual_fields(jc)
        }
      end
    end

    private

    def resolve_individual_fields(join_condition)
      join_condition.each_field { |f|
        Sql::FieldResolver.resolve(@ast, f)
      }
    end

    def resolve_predicate(p)
      Sql::PredicateTranslator.translate(@ast.head, p)
    end
  end
end
