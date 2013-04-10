require 'tpl/lookup_fragment'

module Tpl
  class Gsub < LookupFragment
    def initialize(identifier, pattern, replacement)
      super(identifier)
      @pattern = pattern
      @replacement = replacement
    end

    def eval(provider)
      lookup(provider) { |match|
        match.gsub(Regexp.quote(@pattern)) { |m|
          @replacement.eval(provider)
        }
      }
    end

    def to_s
      "${#{@identifier}//#{@pattern}/#{@replacement}}"
    end
  end
end
