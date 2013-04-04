module Query
  class Term
    attr_accessor :context

    def type
      '*'
    end

    def value?
      false
    end

    # A thing that is not really a term, such as an option.
    def meta?
      false
    end
  end
end
