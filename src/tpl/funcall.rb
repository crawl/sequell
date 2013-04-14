module Tpl
  class Funcall
    include Tplike

    attr_reader :name, :arguments

    def initialize(name, *arguments)
      @name = name
      @arguments = arguments
    end

    def eval(provider)
      if !Template.allow_functions? ||
          !Template.function_executor.fnexists?(self)
        return self.to_s
      end
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
