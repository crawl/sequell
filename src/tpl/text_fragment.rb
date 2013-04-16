require 'tpl/tplike'

module Tpl
  class TextFragment
    include Tplike

    attr_accessor :text

    def initialize(text)
      @text = text.to_s
    end

    def eval(provider)
      @text
    end

    def collapsible?
      false
    end

    def collapse
      self
    end

    def empty?
      !@text || @text.empty?
    end

    def to_s
      @text
    end
  end
end
