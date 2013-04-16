require 'tpl/function_def'

module Tpl
  class FunctionExecutor
    def self.fnexists?(fn, scope)
      FunctionDef.find_definition(fn.name, scope)
    end

    def self.funcall(fncall, scope)
      evaluator = FunctionDef.evaluator(fncall.name, scope)
      if !evaluator
        fncall.to_s
      else
        self.new(fncall, evaluator, scope).eval()
      end
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

    def argvalue(arg)
      arg.is_a?(Tplike) ? arg.eval(@provider) : arg
    end

    def arguments
      @arguments ||= @fn.arguments.map { |arg|
        argvalue(arg)
      }
    end

    def arguments=(args)
      @arguments = args
    end

    def raw_args
      @fn.arguments
    end

    def raw_arg(index)
      @fn.arguments[index]
    end

    def [](index)
      argvalue(@fn.arguments[index])
    end

    def to_s
      @fn.to_s
    end
  end
end
