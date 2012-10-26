module Query
  class QueryStruct
    attr_reader :predicates, :sorts
    def initialize(initial_predicate='AND', *expressions)
      @predicates = [initial_predicate, *expressions]
      @sorts = []
    end

    def operator=(operator)
      @predicates[0] = operator
    end

    def empty?
      @predicates.size == 1
    end

    def atom?
      @predicates.size == 2
    end

    def atom
      return unless self.atom?
      @predicates[1]
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
        if predicate.respond_to?(:predicates)
          @predicates << predicate.body unless predicate.empty?
          @sorts += predicate.sorts
          check_sorts!
        else
          @predicates << predicate
        end
      end
      self
    end

    def << (predicate)
      self.append(predicate)
    end

    def self.or_clause(negated, *predicates)
      return self.new('OR', *predicates) unless negated
      self.new('AND', *predicates)
    end

    def self.and_clause(negated, *predicates)
      return self.new('AND', *predicates) unless negated
      self.new('OR', *predicates)
    end
  end
end
