module Sql
  class Value
    def self.cleanse_input(value)
      return nil unless value
      value.strip.downcase.tr('_', ' ')
    end
  end
end
