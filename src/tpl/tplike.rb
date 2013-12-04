module Tpl
  module Tplike
    def tpl?
      true
    end

    def string(result)
      return result.to_a.join(' ') if result.is_a?(Enumerable)
      result
    end

    def simple?
      false
    end

    def eval(provider)
    end

    def eval_value(val, scope)
      if val.is_a?(Tplike)
        val.eval(scope)
      else
        val
      end
    end

    def collapse
      self
    end

    def empty?
      false
    end

    def collapsible?
      false
    end
  end
end
