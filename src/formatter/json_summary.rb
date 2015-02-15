require 'formatter/graph_json_summary'
require 'json'

module Formatter
  class JSONSummary < GraphJsonSummary
    def format
      ::JSON.generate(super.merge(query: query.ast.to_s))
    end
  end
end
