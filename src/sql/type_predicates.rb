require 'sql/date'

module Sql
  module TypePredicates
    def unit
      self.type.unit
    end

    def text?
      self.type.text?
    end

    def case_sensitive?
      self.type.case_sensitive?
    end

    def date?
      self.type.date?
    end

    def numeric?
      self.type.numeric?
    end

    def real?
      self.type.real?
    end

    def integer?
      self.type.integer?
    end

    def boolean?
      self.type.boolean?
    end

    def display_format
      nil
    end

    def display_value(value)
      self.type.display_value(value, self.display_format)
    end

    def log_value(raw_value)
      self.type.log_value(raw_value)
    end

    def comparison_value(raw_value)
      self.type.comparison_value(raw_value)
    end

    def type_match?(other_type)
      self.type.type_match?(other_type)
    end
  end
end
