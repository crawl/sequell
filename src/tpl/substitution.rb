module Tpl
  class Substitution < LookupFragment
    def initialize(identifier, replacement)
      super(identifier)
      @replacement = replacement
    end

    def eval(provider)
      res = provider[@identifier]
      return @replacement.eval(provider) if res.nil?
      res
    end

    def to_s
      "${#{@identifier}:-#{@replacement}"
    end
  end
end
