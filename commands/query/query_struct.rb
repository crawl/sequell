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

    def primary_sort
      @sorts[0]
    end

    def each(&block)
      @predicates.each(&block)
    end

    def to_sql(table_set, context=Sql::QueryContext.context, parens=false)
      parenthesize(
        self.map { |p|
          p.to_sql(table_set, context, true)
        }.join(" #{operator} "),
        parens)
    end

    def sql_values
      self.map { |p|
        p.sql_values
      }.flatten
    end

    def simple_expression?
      false
    end

    def each_predicate(preds=@predicates)
      preds.each { |p|
        if p.simple_expression?
          yield p
        else
          each_predicate(p)
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
      self.atom || self.predicates
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

    def << (predicate)
      self.append(predicate)
    end

    def to_s
      "Query[#{self.map(&:to_s).join(',')}]"
    end

  private
    def append_predicates(predicate)
      return if predicate.empty?
      @predicates << predicate.body
    end

    def parenthesize(expr, parens=true)
      return expr unless parens
      "(#{expr})"
    end
  end
end
