module Tpl
  class LookupFragment
    attr_reader :identifier

    def initialize(identifier)
      @identifier = identifier
    end

    def lookup(provider)
      value = provider[@identifier]
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
      res = provider[@identifier]
      return self.to_s if res.nil?
      res
    end

    def to_s
      "${#{@identifier}}"
    end
  end
end
