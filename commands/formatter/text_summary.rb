require 'formatter/summary'

module Formatter
  class TextSummary < Summary
    def format
      ("#{summary_count} #{summary_entities} " +
        "for #{@summary.query.argstr}: #{summary_details}")
    end

    def summary_details
      @summary.sorted_row_values.join(", ")
    end
  end
end
