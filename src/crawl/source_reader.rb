require 'set'

module Crawl
  class SourceReader
    def initialize(file, options)
      @file = file
      @options = options || {}
      @options[:dedupe] = true unless @options.include?(:dedupe)
      @options[:fail_on_empty] = true unless @options.include?(:fail_on_empty)
      @options[:collect] = true unless @options.include?(:collect)
    end

    def lines
      start_pattern = @options[:start]
      end_pattern = @options[:end]
      match_pattern = @options[:match]
      dedupe = @options[:dedupe]
      collect = @options[:collect]

      found_start = false
      results = []
      File.open(@file) { |f|
        f.each_line { |line|
          found_start = true if start_pattern && line =~ start_pattern
          if (found_start || !start_pattern) &&
              (!match_pattern || line =~ match_pattern)
            res = yield(line)
            results << res if collect && res
          end
          break if end_pattern && found_start && line =~ end_pattern
        }
      }
      if collect && dedupe
        results = Set.new(results).to_a
      end
      raise "Could not parse #{@file}" if collect && results.empty?
      results
    end
  end
end
