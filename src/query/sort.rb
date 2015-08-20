require 'sql/query_context'
require 'sql/field_predicates'
require 'query/has_expression'
require 'query/ast/group_order_term'

module Query
  class Sort
    attr_reader :direction

    include HasExpression

    def initialize(expr, direction='DESC')
      direction = canonicalize_direction(direction)
      unless direction == 'ASC' || direction == 'DESC'
        raise "Bad sort direction: #{direction}"
      end
      self.expr = expr
      expr.bind_ordered_column! if expr.kind == :field
      @direction = direction
    end

    def kind
      :sort
    end

    def to_group_order_term
      bind(Query::AST::GroupOrderTerm.new(expr, asc? ? '-' : '+'))
    end

    def unique_valued?
      expr.kind == :field && expr.unique_valued?
    end

    def dup
      Sort.new(expr.dup, @direction.dup)
    end

    def asc?
      !desc?
    end

    def desc?
      @direction == 'DESC'
    end

    def reverse
      Sort.new(expr.dup, @direction.upcase == 'DESC' ? 'ASC' : 'DESC')
    end

    def to_sql
      "#{expr.to_sql} #{@direction}"
    end

    def to_s
      (asc? ? 'min' : 'max') + "=#{expr}"
    end

  private

    def canonicalize_direction(dir)
      return 'DESC' if !dir || dir == '' || dir == '+'
      return 'ASC' if dir == '-'
      dir
    end
  end
end
