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

    attr_accessor :scope, :funcall
    def initialize(fn, evaluator, scope)
      @fn = fn
      @evaluator = evaluator
      @scope = scope
    end

    def funcall
      @fn
    end

    def eval
      @evaluator.dup.eval_with(self)
    end

    def arity
      @fn.arity
    end

    def argvalue(arg, scope=@scope)
      arg.is_a?(Tplike) ? arg.eval(scope) : arg
    end

    def eval_arg(index, override_scope=nil)
      argvalue(raw_arg(index), override_scope || @scope)
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
