module Tpl
  class Funcall
    include Tplike

    RECURSE_MAX = 30

    @@funcall_depth = 0

    attr_reader :name, :arguments

    def initialize(name, *arguments)
      @name = name
      @arguments = arguments
    end

    def [](index)
      @arguments[index]
    end

    def funcall_scope
      @@funcall_depth += 1
      begin
        yield
      ensure
        @@funcall_depth -= 1
      end
    end

    def call(scope, *arguments)
      @arguments = arguments
      eval(scope)
    end

    def eval(provider)
      return to_s unless Template.allow_functions?
      # if @@funcall_depth > RECURSE_MAX
      #   raise "Recursion too deep"
      # end
      funcall_scope {
        res = Template.function_executor.funcall(self, provider)
        res
      }
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
