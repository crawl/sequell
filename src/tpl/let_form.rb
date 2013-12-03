module Tpl
  class LetForm
    include Tplike

    attr_reader :name, :bindings, :body
    def initialize(name, bindings, body)
      @name = name
      @bindings = bindings
      @body = body
    end

    def scope_with_bindings(scope)
      binding_map = { }
      @bindings.each { |b|
        binding_map[b.name] = b.value
      }
      LazyEvalScope.new(binding_map, scope)
    end

    def eval(scope)
      @body.eval(scope_with_bindings(scope))
    end

    def binding_str
      "(" + @bindings.map(&:to_s).join(' ') + ")"
    end

    def to_s
      "$(let #{binding_str} #{@body})"
    end
  end
end
