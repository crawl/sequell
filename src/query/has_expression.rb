require 'query/termlike'

module Query
  module HasExpression
    include Termlike

    def expr
      self.first
    end

    def expr=(exp)
      self.arguments = [exp]
    end

    def display_value(raw_value, format=nil)
      expr.display_value(raw_value, format)
    end

    def operator
      nil
    end

    def meta?
      true
    end

    def type
      expr.type
    end

    def to_sql
      expr.to_sql
    end
  end
end
