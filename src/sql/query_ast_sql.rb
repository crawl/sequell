require 'ostruct'

module Sql
  ##
  # Maintains a mapping of expressions to aliases for those expressions.
  # Any expression that
  class TermAliasMap < Hash
    def alias(expr)
      return expr.to_sql_output if expr.simple?
      expr_alias = self[expr.to_s]
      return expr_alias if expr_alias
      expr_alias = unique_alias(expr)
      expr.to_sql_output + " AS #{expr_alias}"
    end

    def unique_alias(expr)
      base = expr.to_s.gsub(/[^a-zA-Z]/, '_').gsub(/_+$/, '') + '_alias'
      known_aliases = Set.new(self.values)
      while  known_aliases.include?(base)
        base += "_0" unless base =~ /_\d+$/
        base = base.gsub(/(\d+)$/) { |m| ($1.to_i + 1).to_s }
      end
      self[expr.to_s] = base
      base
    end
  end

  class QueryASTSQL
    attr_reader :query_ast
    attr_reader :values

    def initialize(query_ast)
      @query_ast = query_ast
      @alias_map = TermAliasMap.new
      @values = []
    end

    def to_sql
      sql_query.sql
    end

    def sql_values
      sql_query.values
    end

  private

    def sql_query
      @sql_query ||= build_query
    end

    def option(key)
      query_ast.option(key)
    end

    def grouped?
      query_ast.summarise
    end

    def build_query
      sql = if subquery? && !exists_query? && !subquery_expression?
              "(#{query_sql}) AS #{query_alias}"
            else
              query_sql
            end
      # Building query also sets values
      OpenStruct.new(sql: sql, values: @values)
    end

    def query_sql
      query_ast.resolve_game_number!

      resolve(query_fields)
      load_values(query_fields)

      query_ast.autojoin_lookup_columns!
      load_values([query_ast.head])

      if query_ast.having
        resolve([query_ast.having])
        load_values([query_ast.having])
      end

      if query_ast.ordered?
        resolve(order_fields)
        load_values(order_fields)
      end

      ["SELECT #{query_columns.join(', ')}",
       "FROM #{query_tables_sql}",
       query_where_clause,
       query_group_by_clause,
       having_clause,
       query_order_by_clause,
       limit_clause].compact.join(' ')
    end

    def query_fields
      query_ast.select_expressions
    end

    def query_columns
      query_fields.map(&:to_sql_output)
    end

    def query_tables_sql
      query_ast.to_table_list_sql
    end

    def query_where_clause
      conds = where_conditions
      return nil if conds.empty?
      "WHERE #{conds}"
    end

    def where_conditions
      query_ast.head.to_sql
    end

    def query_group_by_clause
      return unless grouped?
      "GROUP BY #{query_summary_sql_columns.join(', ')}"
    end

    def having_clause
      return unless grouped? && query_ast.having
      "HAVING #{query_ast.having.to_sql}"
    end

    def query_order_by_clause
      return if query_ast.simple_aggregate? || !order_fields || order_fields.empty?
      "ORDER BY " + order_fields.map(&:to_sql).join(', ')
    end

    def limit_clause
      return if query_ast.summary? && !query_ast.explicit_game_number?

      index = query_ast.game_number
      raise("game_number=#{index}, expected > 0") if !index || index <= 0
      if index == 1
        "LIMIT 1"
      else
        "OFFSET #{index - 1} LIMIT 1"
      end
    end

    def sorts
      @sorts ||= query_ast.sorts
    end

    def query_summary_sql_columns
      query_ast.summarise.arguments.map { |arg|
        if arg.simple?
          arg.to_sql_output
        else
          @alias_map.alias(arg)
        end
      }
    end

    ##
    # Converts expressions on fields that belong in lookup tables into the
    # fields in the lookup tables.
    def resolve(exprs)
      exprs.each { |e|
        e.each_field { |f|
          Sql::FieldResolver.resolve(query_ast, f)
        }
      }
    end

    def load_values(exprs)
      exprs.each { |e|
        e.each_value { |v|
          @values << v.value unless v.null?
        }
      }
    end

    def order_fields
      @order_fields ||= (query_ast.grouped? ? query_ast.group_order.to_a : query_ast.sorts)
    end

    def subquery?
      query_ast.subquery?
    end

    def exists_query?
      query_ast.exists_query?
    end

    def subquery_expression?
      query_ast.subquery_expression?
    end

    def query_alias
      query_ast.alias
    end
  end
end
