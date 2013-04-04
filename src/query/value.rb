require 'query/term'

module Query
  class Value < Term
    attr_reader :value

    def initialize(value)
      @value = value
    end

    def type
      value_type(@value)
    end

    def to_s
      @value.to_s.inspect
    end

    def value_type
      '*'
    end
  end
end
