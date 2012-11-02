require 'formatter/json_summary'

module Formatter
  class GraphSummary
    def format(summary)
      require 'json'

      json_reporter = JsonSummary.new(summary)
      json = json_reporter.format
      File.open("graph.json", 'w') { |f| f.write(json.to_json) }
      "#{json_reporter.prefix}Saved to graph.json"
    end
  end
end
