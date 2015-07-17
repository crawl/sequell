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
        tables.join(join)
      end
    end

    def create_join(join_condition)
      Sql::Join.new(join_condition.left.table, join_condition.right.table,
                    [join_condition.left], :inner,
                    [join_condition.right])
    end

    def sanity_check!
      # Table aliases are guaranteed unique, so check those:
      table_aliases = Set.new
      table_aliases << tables.primary_table.alias
      for join in tables.joins
        table_aliases << join.left_table.alias
        table_aliases << join.right_table.alias
      end

      if table_aliases.size != tables.tables.size
        raise "Bad join: #{table_aliases.size} tables joined, but #{tables.tables.size} tables are referenced: #{tables.joins.map(&:to_s).join(' ')}"
      end
    end
  end
end
