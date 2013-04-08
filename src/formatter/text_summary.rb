require 'formatter/summary'

module Formatter
  class TextSummary < Summary
    def format
      ("#{result_prefix_title}: #{summary_details}")
    end

    def result_prefix_title
      return default_result_prefix_title if default_result_prefix_title
      "#{summary_count} #{summary_entities} for #{@summary.query.argstr}"
    end

    def summary_details
      @summary.sorted_row_values.join(", ")
    end
  end
end
