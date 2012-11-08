module Formatter
  class Summary
    def self.format(summary)
      self.new(summary).format
    end

    def initialize(summary)
      @summary = summary
    end

    def query
      @summary.query
    end

    def prefix
      "#{summary_count} #{summary_entities} for #{@summary.query.argstr}: "
    end

    def format
      "#{prefix}#{summary_details}"
    end

    def counts
      @summary.counts
    end

    def count
      @summary.counts[0]
    end

    def summary_count
      if self.counts.size == 1
        self.count == 1 ? "One" : "#{self.count}"
      else
        self.counts.reverse.join("/")
      end
    end

    def summary_entities
      type = query.ctx.entity_name
      self.count == 1 ? type : type + 's'
    end

    def summary_details
      raise "Unimplemented"
    end
  end
end
