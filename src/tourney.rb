require 'yaml'

module Tourney
  CFG = YAML.load_file(LG_CONFIG_FILE)

  TOURNEY_SPRINT_MAP = CFG['tournament-sprint-map']
  TOURNEY_PREFIXES = CFG['tournament-prefixes']
  TOURNEY_VERSIONS = CFG['tournament-versions']
  TOURNEY_DATA = CFG['tournament-data']
  SPRINT_TOURNEY_DATES =

  TOURNEY_REGEXES = TOURNEY_PREFIXES.map do |p|
    %r/^(#{p})(\d*)([a-z]?)$/i
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
      date.to_s.sub(/^(\d{4})(\d{2})(\d{2})/) { |m|
        "#$1#{sprintf('%02d', $2.to_i - 1)}#$3"
      }
    end

    def resolve_year(val)
      year = TOURNEY_DATA['default-tourney']
      for reg in TOURNEY_REGEXES
        if val =~ reg && $2 && !$2.empty?
          year = $2.to_i
          suffix = $3
          year += 2000 if year < 100
          year = "#{year}#{suffix}"
          break
        end
      end
      year
    end
  end
end
