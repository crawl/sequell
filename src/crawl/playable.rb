require 'crawl/source'
require 'json'

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
      playable_things = JSON.parse(%x{#{Source.crawl_executable} -playable-json})
      @species = playable_things["species"].find_all { |sp| !sp["derives"] }.
                                            map { |sp| sp["name"] }
      @jobs = playable_things["jobs"].map { |j| j["name"] }
      @combos = playable_things["combos"]
    end
  end
end
