require 'crawl/config'

module Tourney
  CFG = Crawl::Config.config

  TOURNEY_SPRINT_MAP = CFG['tournament-sprint-map']
  TOURNEY_PREFIXES = CFG['tournament-prefixes']
  TOURNEY_VERSIONS = CFG['tournament-versions']
  TOURNEY_DATA = CFG['tournament-data']

  TOURNEY_REGEXES = TOURNEY_PREFIXES.map do |p|
    %r/^(#{p})(?:(\d*)([a-z]?)|(\d*[.]\d+))$/i
  end

  def tourney_keyword?(argument)
    TOURNEY_REGEXES.find { |r| argument =~ r }
  end

  def tourney_info(argument, game = GAME_TYPE_DEFAULT)
    TourneyInfo.new(argument, game)
  end

  class TourneyInfo
    attr_reader :tstart, :tend, :tmap, :version

    def initialize(tournament_key, game_type)
      @key = tournament_key
      @game_type = game_type
      @year = resolve_year(@key)
      unless tourney_data[@year]
        raise StandardError.new("Unknown tournament: #{tournament_key}")
      end
      @tmap = nil

      @version = tourney_data[@year]['version']
      @version = [@version] unless @version.is_a?(Array)
      @version = @version.map(&:strip)
      resolve_time!
      resolve_map!
    end

    def tourney_data
      (TOURNEY_DATA[@game_type] or
        raise StandardError.new("No tournament data for #{@game_type}"))
    end

    def resolve_map!
      @tmap = tourney_data[@year]['map']
      @tmap.strip! if @tmap
    end

    def resolve_time!
      range = tourney_data[@year]['time']
      raise StandardError.new("No tourney information for #{@year}") unless range
      @tstart = raw_date(range[0])
      @tend = raw_date(range[1])
    end

    ##
    # Convert a regular YYYYMMDD date into a POSIX date with 0-indexed months.
    def raw_date(date)
      date
    end

    def tourney_for_version(version)
      tourneys = TOURNEY_DATA['crawl']
      tourneys.keys.each { |key|
        tourney = tourneys[key]
        versions = tourney['version']
        versions = [versions] unless versions.is_a?(Enumerable)
        if versions.any? { |v| v.index(version) }
          return key
        end
      }
      raise "Unknown tourney version: #{version}"
    end

    def resolve_year(val)
      year = TOURNEY_DATA['default-tourney']
      for reg in TOURNEY_REGEXES
        if val =~ reg
          if $2 && !$2.empty?
            year = $2.to_i
            suffix = $3
            year += 2000 if year < 100
            year = "#{year}#{suffix}"
            break
          elsif $4
            version = $4
            return tourney_for_version(version)
          end
        end
      end
      year
    end
  end
end
