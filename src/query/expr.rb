require 'query/operators'

module Query
  class Expr
    def self.and(arguments)
      self.new(Query::Operator.op(:and), arguments)
    end

    attr_reader :operator, :arguments

    def initialize(operator, arguments)
      @operator = operator
      @arguments = arguments.compact
    end

    def typecheck!
      operator.typecheck!(args)
    end

    def type
      operator.result_type(args)
    end
  end
end
