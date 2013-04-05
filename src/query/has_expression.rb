require 'query/termlike'

module Query
  module HasExpression
    def operator
      nil
    end

    def type
      nil
    end

    def arguments
      [expr]
    end

    include Termlike
  end
end
