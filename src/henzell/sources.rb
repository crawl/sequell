require 'henzell/config'
require 'yaml'

module Henzell
  class Sources
    SOURCES_FILE = 'config/sources.yml'

    def self.sources_file
      Henzell::Config.file_path(SOURCES_FILE)
    end

    def self.instance
      @instance ||= self.new(self.sources_file)
    end

    def self.config
      self.instance
    end

    attr_reader :sources

    def initialize(config_file)
      @config_file = @config_file
      @config = YAML.load_file(config_file)
      require 'henzell/source'
      @sources ||= @config['sources'].map { |source_cfg|
        Source.new(source_cfg)
      }
      @source_map = Hash[ @sources.map { |s| [s.name, s] } ]
      @alias_map =
        Hash[@sources.map { |s| s.aliases.map { |a| [a, s.name] } }.flatten(1)]
    end

    def source_abbreviations
      self.sources.map(&:name)
    end

    def source_names
      @source_names ||= self.sources.map(&:name)
    end

    def source_aliases
      @source_aliases ||= self.sources.map { |src| src.aliases }.flatten
    end

    def source_names_and_aliases
      source_names + source_aliases
    end

    def source?(name)
      source_names_and_aliases.include?(name.downcase)
    end

    def canonical_source(name)
      @alias_map[name.downcase] || name.downcase
    end

    def source(name)
      @source_map[name] or raise StandardError, "Unknown game source: #{name}"
    end

    def source_for(game)
      self.source(game['src'])
    end

    def morgue_for(game)
      require 'henzell/morgue_resolver'
      MorgueResolver.new(self, game).morgue
    end

    def crash_dump_for(game)
      require 'henzell/morgue_resolver'
      MorgueResolver.new(self, game).crash_dump
    end

    def ttyrecs_for(game)
      require 'henzell/ttyrec_search'
      TtyrecSearch.ttyrecs(self.source_for(game), game)
    end
  end
end
