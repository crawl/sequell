module Tpl
  module Tplike
    def tpl?
      true
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
