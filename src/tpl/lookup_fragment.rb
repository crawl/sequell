module Tpl
  class LookupFragment < Fragment
    attr_reader :identifier

    def self.fragment(thing)
      return thing if thing.is_a?(LookupFragment)
      self.new(thing)
    end

    def initialize(identifier, subscript=nil)
      @identifier = identifier
      @subscript = subscript
      if @identifier.is_a?(LookupFragment) && @identifier.simple?
        @identifier = @identifier.identifier
      end
      @stringy = @identifier.is_a?(String)
    end

    def subscripted?
      @subscript
    end

    def subscript
      @subscript
    end

    def simple?
      true
    end

    def collapsible?
      false
    end

    def subscripted(value)
      return value unless value && subscripted?
      value = value.split(';;;;') if value.is_a?(String)
      value[subscript]
    end

    def raw_value(provider)
      if subscripted?
        provider["@#{@identifier}"] || provider[@identifier]
      else
        provider[@identifier]
      end
    end

    def value_str(provider)
      subscripted(@stringy ? raw_value(provider) : @identifier.eval(provider))
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
      qualifier = "[#{@subscript}]" if @subscript
      "${#{@identifier}#{qualifier}}"
    end
  end
end
