module Henzell
  module Server
    class MorguePredicate
      REGISTRY = { }

      def self.compile(predicates)
        self.new(predicates)
      end

      def self.register(key, cls)
        REGISTRY[key] = cls
      end

      def self.predicate_named(name)
        REGISTRY[name] or die "Unknown predicate: #{name}"
      end

      def initialize(predicates)
        @clauses = predicates.map { |predicate, arguments|
          compile_predicate(predicate, arguments)
        }
      end

      def matches?(game)
        @clauses.all? { |clause| clause.matches?(game) }
      end

    private
      def compile_predicate(predicate, arguments)
        arguments = [arguments] unless arguments.is_a?(Array)
        self.class.predicate_named(predicate).new(predicate, *arguments)
      end
    end

    class TimeGt
      MorguePredicate.register('time_gt', self)

      def initialize(name, value)
        @value = value
      end

      def matches?(game)
        format_time(game_time(game)) > @value
      end

      def game_time(game)
        game['end'] || game['rend'] || game['time'] || game['rtime']
      end

    private
      def format_time(time)
        time.sub(/^(\d{4})(\d{2})(\d{2})(\d{4,}).*/) { |match|
          $1 + sprintf('%02d', ($2.to_i + 1)) + $3 + '-' + $4
        }
      end
    end

    class VersionMatch
      MorguePredicate.register('version_match', self)

      def initialize(name, version)
        @version = version
      end

      def matches?(game)
        game['v'] =~ /^#{Regexp.quote(@version)}(?:[.-]|$)/
      end
    end
  end
end
