module Henzell
  module Server
    class MorgueFilename
      def self.name(path, game, prefix='morgue', extension='.txt')
        self.new(path, game, extension, prefix).name
      end

      attr_reader :path, :game, :extension, :prefix

      def initialize(path, game, extension='.txt', prefix='morgue')
        @game = game
        @path = resolve_path(path, game)
        @extension = extension
        @prefix = prefix
      end

      def player
        @game['name']
      end

      def time
        morgue_time(@game)
      end

      def name
        @name ||= lookup_morgue
      end

      def ancient_version?
        require 'sql/version_number'
        Sql::VersionNumber.version_numberize(@game['v']) <
          Sql::VersionNumber.version_numberize('0.4')
      end

    private
      def resolve_path(path, game)
        path.gsub(/:(\w+)/) { |match|
          key = $1
          if key == 'prefix_v'
            game['v'].sub(/^(\d+[.]\d+).*/, '\1')
          else
            game[key] || ":#{key}"
          end
        }
      end

      def lookup_morgue
        return binary_search if ancient_version?
        simple_name
      end

      def simple_name
        (path + '/' + self.player + '/' + self.prefix + '-' + self.player +
          '-' + self.time + self.extension)
      end

      def binary_search
        require 'henzell/server/morgue_binary_search'
        MorgueBinarySearch.search(path, game)
      end
    end
  end
end
