require 'henzell/server/morgue_filename'
require 'henzell/server/morgue_predicate'

module Henzell
  module Server
    class MorguePath
      def initialize(server, path)
        @server = server
        @path = path
      end

      def morgue_url(game, type='morgue')
        morgue_matcher.morgue_url(game, type)
      end

      def to_s
        @path.inspect
      end

    private
      def morgue_matcher
        @morgue_matcher ||=
          if @path.is_a?(Array)
            pattern = @path[0]
            path = @path[1]
            if pattern.is_a?(Hash)
              PredicateMatcher.new(pattern, path)
            else
              FilePatternMatcher.new(pattern, path)
            end
          else
            SimpleMorgueMatcher.new(@path)
          end
      end
    end

    class SimpleMorgueMatcher
      def initialize(path)
        @path = path
      end

      def morgue_url(game, type)
        MorgueFilename.name(@path, game, type)
      end
    end

    class FilePatternMatcher
      def initialize(pattern, path)
        @pattern = Regexp.new(pattern)
        @path = path
      end

      def morgue_url(game, type)
        match = @pattern.match(game['file'])
        return nil unless match
        url = @path.gsub(/\$(\d+)/) { |m|
          match[$1.to_i]
        }
        MorgueFilename.name(url, game, type)
      end
    end

    class PredicateMatcher
      def initialize(predicates, path)
        @predicates = MorguePredicate.compile(predicates)
        @path = path
      end

      def morgue_url(game, type)
        MorgueFilename.name(@path, game, type) if @predicates.matches?(game)
      end
    end
  end
end
