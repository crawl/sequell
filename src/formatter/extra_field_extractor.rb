require 'formatter/util'

module Formatter
  class ExtraFieldExtractor
    def ratio(numerator, denominator)
      return 0 if denominator <= 0
      numerator.to_f / denominator
    end

    def self.extractor(summary, numeric_fields)
      extra_fields = summary.extra_fields
      indexed_fields = numeric_fields.map { |ef|
        index = extra_fields.index(ef)
        [ef, index] if index
      }.compact
      n_fields = indexed_fields.size
      if summary.ratio_query?
        lambda { |row|
          res = []
          for field, index in indexed_fields
            res << Formatter.ratio(row.extra_values[index][1],
                                   row.extra_values[index][0])
          end
          res
        }
      else
        lambda { |row|
          res = []
          for field, index in indexed_fields
            res << row.value_string(row.extra_values[index], field).to_f
          end
          res
        }
      end
    end
  end
end
