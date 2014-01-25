require 'tpl/tplike'

module Tpl
  class TextFragment
    include Tplike

    attr_accessor :text

    def self.translate_escape(text)
      text.gsub(/\\n/, "\n")
    end

    def initialize(text)
      @text = text
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
      !@text || @text.to_s.empty?
    end

    def << (other)
      @text = @text.to_s
      @text << other.to_s
      self
    end

    def to_s
      @text.to_s
    end
  end
end
