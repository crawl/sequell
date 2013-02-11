require 'crawl/config'

module Crawl
  class MilestoneType
    def self.aliases
      @aliases ||= config['milestone-aliases'] || { }
    end

    def self.types
      @types ||= config['milestone-types'] + self.aliases.keys
    end

    def milestone?(milestone)
      self.canonicalize(milestone)
    end

    def self.canonicalize(milestone)
      milestone = milestone.to_s.strip.downcase
      return nil if milestone.size <= 2

      match = best_match(milestone)
      return nil unless match
      self.aliases[match] || match
    end

    def self.best_match(milestone)
      # Exact match always wins.
      return milestone if self.types.include?(milestone)

      # No exact match, look for a substring match:
      matches = self.types.select { |type|
        type.index(milestone) == 0 || milestone.index(type) == 0
      }
      return nil if matches.empty?

      # Prefer the longest match:
      matches = matches.sort { |a, b| b.size <=> a.size }

      # Reject ambiguous matches
      return nil if matches.size > 1 && matches[1].size == matches[0].size

      matches.first
    end

    def self.config
      Crawl::Config.config
    end
  end
end
