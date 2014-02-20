module Tpl
  class LetForm
    include Tplike

    attr_reader :name, :bindings, :body_forms
    def initialize(name, bindings, body_forms)
      @name = name
      @bindings = bindings
      @body_forms = body_forms
    end

    def scope_with_bindings(scope)
      binding_map = { }
      @bindings.each { |b|
        binding_map[b.name] = b.value
      }
      LazyEvalScope.new(binding_map, scope)
    end

    def eval(scope)
      dynamic_scope = scope_with_bindings(scope)
      res = nil
      @body_forms.each { |form|
        res = eval_value(form, dynamic_scope)
      }
      res
    end

    def binding_str
      "(" + @bindings.map(&:to_s).join(' ') + ")"
    end

    def to_s
      "$(let #{binding_str} #{@body_forms.join(' ')})"
    end
  end

  class LetXForm < LetForm
    def scope_with_bindings(original_scope)
      @bindings.reduce(original_scope) { |scope, binding|
        LazyEvalScope.new({ binding.name => binding.value }, scope)
      }
    end
  end
end
