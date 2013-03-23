require 'sql/field_predicate'
require 'sql/query_context'

module Query
  class QueryStruct
    def self.or_clause(negated, *predicates)
      return self.new('OR', *predicates) unless negated
      self.new('AND', *predicates)
    end

    def self.and_clause(negated, *predicates)
      return self.new('AND', *predicates) unless negated
      self.new('OR', *predicates)
    end

    include Enumerable

    attr_reader :predicates
    attr_accessor :operator, :sorts

    def initialize(operator='AND', *expressions)
      @operator = operator
      @predicates = expressions
      @sorts = []
    end

    def negate
      if self.predicates.size == 1
        QueryStruct.new(self.operator, self.predicates[0].negate)
      else
        QueryStruct.new('AND', QueryStruct.new('NOT', self))
      end
    end

    def dup
      copy = QueryStruct.new(@operator.dup, * @predicates.map { |p| p.dup })
      copy.sorts = @sorts.map { |s| s.dup }
      copy
    end

    def not?
      @operator == 'NOT'
    end

    def or?
      @operator == 'OR'
    end

    def and?
      @operator == 'AND'
    end

    def reverse_sorts!
      @sorts = @sorts.map { |s| s.reverse }
    end

    def primary_sort
      @sorts[0]
    end

    def each(&block)
      @predicates.each(&block)
    end

    def to_sql(table_set, context=Sql::QueryContext.context, parens=false)
      parenthesize(self.sql_expr(table_set, context), parens)
    end

    def sql_expr(table_set, context)
      # Try to identify IN clauses for more readable queries.
      if @predicates.size > 1 && @predicates.all? { |p| p.simple_expression? }
        first = @predicates[0]
        if (((first.operator === '=' && self.or?) ||
              (first.operator === '!=' && self.and?)) &&
            @predicates.all? { |p| p.condition_match?(first) })
          return sql_in_clause(table_set, context)
        end
      end

      assert_well_formed!

      if not?
        "NOT " + self.predicates.first.to_sql(table_set, context, true)
      else
        self.map { |p|
          p.to_sql(table_set, context, true)
        }.join(" #{operator} ")
      end
    end

    def assert_well_formed!
      !not? || @predicates.size == 1
    end

    def sql_values
      self.map { |p|
        p.sql_values
      }.flatten
    end

    def simple_expression?
      false
    end

    def each_predicate(preds=@predicates, &block)
      preds.each { |p|
        if p.simple_expression?
          block.call(p)
        else
          each_predicate(p, &block)
        end
      }
    end

    def empty?
      @predicates.empty?
    end

    def atom?
      @predicates.size == 1
    end

    def atom
      return unless self.atom?
      @predicates[0]
    end

    def body
      self.atom || self
    end

    def without_sorts
      copy = self.dup
      copy.sorts = []
      copy
    end

    def sort(sort)
      @sorts << sort
      check_sorts!
      self
    end

    def has_sorts?
      !@sorts.empty?
    end

    def check_sorts!
      raise "Too many sort conditions" if @sorts.size > 1
    end

    def append(predicate)
      if predicate
        if predicate.is_a?(Sql::FieldPredicate)
          @predicates << predicate
        else
          unless predicate.is_a?(self.class)
            raise "Bad predicate #{predicate} appended to #{self}"
          end
          append_predicates(predicate)
          @sorts += predicate.sorts
          check_sorts!
        end
      end
      self
    end

    def append_all(predicates)
      predicates.each { |p| self << p }
      self
    end

    def << (predicate)
      self.append(predicate)
    end

    def to_s
      "Query[#{self.map(&:to_s).join(' ' + @operator + ' ')}]"
    end

    def inspect
      self.to_s
    end

  private
    def append_predicates(predicate)
      return if predicate.empty?

      body = predicate.body
      if body.operator == self.operator
        @predicates += body.predicates
      else
        @predicates << body
      end
    end

    def parenthesize(expr, parens=true)
      return expr unless parens
      "(#{expr})"
    end

    def sql_in_clause(table_set, context)
      op = self.or? ? 'IN' : 'NOT IN'
      first = @predicates[0]
      placeholders = (['?'] * @predicates.size).join(", ")
      "#{first.sql_field_expr(table_set)} #{op} (#{placeholders})"
    end
  end
end
