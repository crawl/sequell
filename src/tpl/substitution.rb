module Tpl
  class Substitution < LookupFragment
    def initialize(identifier, replacement)
      super(identifier)
      @replacement = replacement
    end

    def eval(provider)
      res = value_str(provider)
      return @replacement.eval(provider) if res.nil? || res.empty?
      return self.to_s if res.nil?
      res
    end

    def simple?
      false
    end

    def to_s
      "${#{@identifier}:-#{@replacement}}"
    end
  end
end
