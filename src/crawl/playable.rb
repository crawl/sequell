require 'crawl/source'

module Crawl
  class Playable
    def self.instance
      @playable ||= self.new
    end

    def self.species
      instance.species
    end

    def self.jobs
      instance.jobs
    end

    def self.combos
      instance.combos
    end

    attr_reader :species, :jobs, :combos
    def initialize
      load_playable
    end

  private

    def load_playable
      playable_things = %x{#{Source.crawl_executable} -list-combos}
      @species, @jobs, @combos = playable_things.split("\n").map { |s|
        s.strip.split(",")
      }
    end
  end
end
