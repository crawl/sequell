require 'sql/date'

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

    def display_format
      nil
    end

    def display_value(value)
      return Sql::Date.display_date(value, self.display_format) if self.date?
      if value.is_a?(BigDecimal) || value.is_a?(Float)
        rawv = sprintf("%.2f", value)
        rawv.sub!(/([.]\d*?)0+$/, '\1')
        rawv.sub!(/[.]$/, '')
        return rawv
      end
      value
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
