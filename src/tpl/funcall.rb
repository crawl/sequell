module Tpl
  class Funcall
    include Tplike

    attr_reader :name, :arguments

    def initialize(name, *arguments)
      @name = name
      @arguments = arguments
    end

    def [](index)
      @arguments[index]
    end

    def call(scope, *arguments)
      @arguments = arguments
      eval(scope)
    end

    def eval(provider)
      Template.function_executor.funcall(self, provider)
    end

    def arity
      @arguments.size
    end

    def inspect
      "Funcall[#{@name}#{@arguments.inspect}]"
    end

    def to_s
      "$(" + ([@name] + @arguments).join(' ') + ")"
    end
  end
end
