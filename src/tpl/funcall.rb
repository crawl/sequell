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

    def funcall
      @@funcall_depth += 1
      begin
        yield
      ensure
        @@funcall_depth -= 1
      end
    end

    def eval(provider)
      if !Template.allow_functions? ||
          !Template.function_executor.fnexists?(self, provider)
        return self.to_s
      end
      if @@funcall_depth > RECURSE_MAX
        raise "Recursion too deep"
      end
      funcall {
        Template.function_executor.funcall(self, provider)
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
