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
