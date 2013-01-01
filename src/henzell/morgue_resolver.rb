module Henzell
  class MorgueResolver
    def initialize(sources, game)
      @sources = sources
      @source = @sources.source(game['src'])
      @game = game
    end

    def morgue(type='morgue')
      morgue_paths.each { |morgue_path|
        resolved_morgue = morgue_path.morgue_url(@game, type)
        return resolved_morgue if resolved_morgue
      }
      nil
    end

    def crash_dump
      self.morgue('crash')
    end

  private
    def morgue_paths
      @source.morgue_paths
    end
  end
end
