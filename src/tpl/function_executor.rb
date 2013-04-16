require 'tpl/function_def'

module Tpl
  class FunctionExecutor
    def self.fnexists?(fn, scope)
      FunctionDef.evaluator(fn.name, scope)
    end

    def self.funcall(fn, scope)
      evaluator = FunctionDef.evaluator(fn.name, scope) or
        raise "Unknown function: #{fn.name}"
      self.new(fn, evaluator, scope).eval()
    end

    attr_reader :provider, :funcall
    def initialize(fn, evaluator, provider)
      @fn = fn
      @evaluator = evaluator
      @provider = provider
    end

    def funcall
      @fn
    end

    def eval
      @evaluator.eval_with(self)
    end

    def arity
      @fn.arity
    end

    def arguments
      @arguments ||= @fn.arguments.map { |arg|
        arg.eval(@provider)
      }
    end

    def raw_arg(index)
      @fn.arguments[index]
    end

    def [](index)
      arg = @fn.arguments[index]
      arg && arg.eval(@provider)
    end

    def to_s
      @fn.to_s
    end
  end
end
