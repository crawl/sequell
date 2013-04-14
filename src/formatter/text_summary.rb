require 'formatter/summary'

module Formatter
  class TextSummary < Summary
    def format
      ("#{result_desc}#{summary_details}")
    end

    def result_desc
      title = self.result_prefix_title
      return '' if !title || title.empty?
      "#{title}: "
    end

    def result_prefix_title
      return default_result_prefix_title if default_result_prefix_title
      return '' if CommandContext.subcommand?
      "#{summary_count} #{summary_entities} for #{@summary.query.argstr}"
    end

    def summary_details
      Tpl::Template.without_subcommands {
        @summary.sorted_row_values.join(default_join)
      }
    end
  end
end
