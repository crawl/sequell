module Sql
  class Error < StandardError
  end

  class ParseError < Error
  end

  class UnknownFieldError < ParseError
    attr_reader :field
    def initialize(field)
      super("Unknown field: #{field}")
      @field = field
    end
  end

  class UnknownFunctionError < ParseError
    attr_reader :function
    def initialize(function)
      super("No non-aggregate function \`#{function}\`")
      @function = function
    end
  end

  class FunctionTypeMismatch < ParseError
    attr_reader :function, :expr

    def initialize(function, expr)
      super("Cannot apply function #{function}() to #{expr}: type mismatch")
      @function = function
      @expr = expr
    end
  end

  class MalformedTermError < ParseError
    def initialize(term)
      super("Malformed term: #{term}")
    end
  end
end
