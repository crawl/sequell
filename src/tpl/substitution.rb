module Tpl
  class Substitution < LookupFragment
    def initialize(identifier, replacement)
      super(identifier)
      @replacement = replacement
    end

    def eval(provider)
      res = value_str(provider)
      res = self.nvl if res.nil?
      return @replacement.eval(provider) if res.nil? || res.empty?
      res
    end

    def simple?
      false
    end

    def to_s
      "${#{qualified_identifier}:-#{@replacement.to_s}}"
    end
  end
end
