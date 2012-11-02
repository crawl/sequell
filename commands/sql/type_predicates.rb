module Sql
  module TypePredicates
    def text?
      text_type?(self.type)
    end

    def case_sensitive?
      self.type == 'S'
    end

    def date?
      self.type == 'D'
    end

    def numeric?
      self.integer?
    end

    def integer?
      self.type == 'I'
    end

    def boolean?
      self.type == '!'
    end

    def type_match?(other_type)
      other_type == '*' || (other_type == self.type) ||
        (text_type?(other_type) && text?)
    end

    def text_type?(type_string)
      !type_string || type_string.empty? || type_string == 'S'
    end
  end
end
