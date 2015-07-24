module Sql
  ##
  # Resolves query_ast join_conditions, binding the tables involved to the
  # query_ast's query_tables via joins. Rejects joins where each not all tables
  # in the result are connected (i.e. reject cartesian products of tables with no
  # join conditions).
  class JoinResolver
    def self.resolve(query_ast)
      self.new(query_ast).resolve
    end

    attr_reader :query_ast

    def initialize(query_ast)
      @query_ast = query_ast
    end

    def resolve
      STDERR.puts("JoinResolver join conditions: #{query_ast.join_conditions.map(&:to_s)} for #{query_ast}")
      query_ast.join_conditions.each { |jc|
        join = create_join(jc)
        apply_join(join)
      }
      sanity_check!
    end

  private

    def tables
      @tables ||= query_ast.query_tables
    end

    def apply_join(join)
      old_join = tables.find_join(join)
      if old_join
        old_join.merge!(join)
      else
        STDERR.puts("JoinResolver: joining #{join} into #{tables}")
        tables.join(join)
      end
    end

    def create_join(join_condition)
      left_table = field_table(join_condition.left)
      right_table = field_table(join_condition.right)
      Sql::Join.new(left_table, right_table,
                    [join_condition.left], :inner,
                    [join_condition.right])
    end

    def field_table(field)
      field.context.resolve_column(field, :internal_expr).table
    rescue
      require 'pry'
      binding.pry
      raise
    end

    def sanity_check!
      # Table aliases are guaranteed unique, so check those:
      table_aliases = Set.new
      table_aliases << tables.primary_table.alias
      for join in tables.joins
        table_aliases << join.left_table.alias
        table_aliases << join.right_table.alias
      end

      # The join resolver only looks at join conditions, so it can't be sure if
      # there are references to columns aimed directly at the primary table,
      # so accept both the with/without primary table cases:
      table_delta = table_aliases.size - tables.tables.size
      if table_delta < 0 || table_delta > 1
        raise "Bad join: #{table_aliases.size} tables joined, but #{tables.tables.size} tables are referenced: #{tables.joins.map(&:to_s).join(' ')}"
      end
    end
  end
end
