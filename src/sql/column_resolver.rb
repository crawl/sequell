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
      @ast.head.each_field { |f|
        STDERR.puts("ColumnResolver: visiting field: #{f}")
        Sql::FieldResolver.resolve(@ast, f)
      }
      if @ast.respond_to?(:join_conditions)
        @ast.join_conditions.each { |jc|
          resolve_join_condition(jc)
        }
      end
    end

    private

    def resolve_join_condition(join_condition)
      if binary_field_predicate?(join_condition)
        resolve_simple_join(join_condition)
      else
        resolve_individual_fields(join_condition)
      end
    end

    def resolve_individual_fields(join_condition)
      join_condition.each_field { |f|
        Sql::FieldResolver.resolve(@ast, f)
      }
    end

    def binary_field_predicate?(jc)
      jc.boolean? && jc.arity == 2 && jc.left.kind == :field && jc.right.kind == :field
    end

    def resolve_simple_join(jc)
      return if jc.left.resolved? && jc.right.resolved?

      left_col = jc.left.column
      right_col = jc.right.column

      # If this is a simple equality comparison of the same column, replace the fields by their lookup columns
      join_by_fk = left_col.lookup_field_name == right_col.lookup_field_name
      if join_by_fk
        jc.left.table = left_col.table
        jc.left.sql_name = left_col.lookup_field_name
        jc.right.table = right_col.table
        jc.right.sql_name = right_col.lookup_field_name
      else
        resolve_individual_fields(jc)
      end
    end

    def resolve_predicate(p)
      Sql::PredicateTranslator.translate(@ast.head, p)
    end
  end
end
