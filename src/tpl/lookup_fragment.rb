module Tpl
  class LookupFragment < Fragment
    attr_reader :identifier

    @@nvl = nil

    def self.with_nvl(nvl)
      old_nvl = @@nvl
      @@nvl = nvl
      begin
        yield
      ensure
        @@nvl = old_nvl
      end
    end

    def self.nvl
      @@nvl
    end

    def self.fragment(thing)
      return thing if thing.is_a?(LookupFragment)
      self.new(thing)
    end

    def initialize(identifier, subscript=nil)
      @identifier = identifier
      @subscript = subscript
      if !@subscript && identifier.respond_to?(:subscript)
        @subscript = identifier.subscript
      end
      @eval_subscript = @subscript.is_a?(Tplike)
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

    def subscripted(value, scope)
      return value unless value && subscripted?
      value = value.split(';;;;') if value.is_a?(String)
      subscript_value = @eval_subscript ? subscript.eval(scope) : subscript
      value[subscript_value]
    end

    def raw_value(provider)
      if subscripted?
        provider["@#{@identifier}"] || provider[@identifier]
      else
        provider[@identifier]
      end
    end

    def value_str(provider)
      subscripted(@stringy ? raw_value(provider) : @identifier.eval(provider),
                  provider)
    end

    def lookup(provider)
      value = self.value_str(provider)
      if !value.nil?
        yield value
      else
        self.nvl
      end
    end

    def nvl
      nvl_val = self.class.nvl
      nvl_val.nil? ? to_s : nvl_val
    end

    def collapse
      self
    end

    def eval(provider)
      res = value_str(provider)
      return res.nil? ? self.nvl : res
    end

    def to_s
      "${#{qualified_identifier}}"
    end

    protected

    def qualified_identifier
      qualifier = "[#{@subscript}]" if @subscript
      "#{@identifier}#{qualifier}"
    end
  end
end
