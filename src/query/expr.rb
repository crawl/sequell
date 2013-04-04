require 'query/operators'
require 'query/term'

module Query
  class Expr < Term
    def self.and(*arguments)
      self.new(Query::Operator.op(:and), *arguments)
    end

    attr_reader :operator, :arguments

    def initialize(operator, *arguments)
      @operator = Query::Operator.op(operator)
      @arguments = arguments.compact
    end

    def typecheck!
      operator.typecheck!(args)
    end

    def type
      operator.result_type(args)
    end

    def to_s
      "(#{operator.to_s} " + arguments.map(&:to_s).join(' ') + ")"
    end
  end
end
