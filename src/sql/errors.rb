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

  class MalformedTermError < ParseError
    def initialize(term)
      super("Malformed term: #{term}")
    end
  end
end
