module Tpl
  class LookupFragment < Fragment
    attr_reader :identifier

    def self.fragment(thing)
      return thing if thing.is_a?(LookupFragment)
      self.new(thing)
    end

    def initialize(identifier)
      @identifier = identifier
      if @identifier.is_a?(LookupFragment) && @identifier.simple?
        @identifier = @identifier.identifier
      end
      @stringy = @identifier.is_a?(String)
    end

    def simple?
      true
    end

    def collapsible?
      false
    end

    def value_str(provider)
      @stringy ? provider[@identifier] : @identifier.eval(provider)
    end

    def lookup(provider)
      value = self.value_str(provider)
      if !value.nil?
        yield value
      else
        to_s
      end
    end

    def collapse
      self
    end

    def eval(provider)
      res = value_str(provider)
      return self.to_s if res.nil?
      res
    end

    def to_s
      "${#{@identifier}}"
    end
  end
end
