module Tpl
  class TextFragment
    def initialize(text)
      @text = text.to_s
    end

    def eval(provider)
      @text
    end

    def collapse
      self
    end

    def to_s
      @text
    end
  end
end
