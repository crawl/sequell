module Formatter
  def self.ratio(numerator, denominator)
    return 0 if denominator <= 0
    numerator.to_f / denominator
  end
end
