require 'json'
require 'date'

module Formatter
  class JSON
    def self.format(result)
      self.new(result).format
    end

    attr_reader :result
    def initialize(result)
      @result = result
    end

    def query
      result.query
    end

    def format
      ::JSON.generate(
        resultTime: DateTime.now.rfc3339,
        entity: query.ctx.entity_name,
        records: result.map(&:as_json))
    end
  end
end
