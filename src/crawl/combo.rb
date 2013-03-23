require 'crawl/config'
require 'crawl/source'

module Crawl
  class Combo
    def self.available_combos
      all_combos
    end

    def self.all_combos
      @all_combos ||= bad_combos + good_combos
    end

    def self.bad_combos
      read_combos unless @bad_combos
      @bad_combos
    end

    def self.good_combos
      read_combos unless @good_combos
      @good_combos
    end

    attr_reader :species, :job
    def initialize(species, job=nil)
      if species.is_a?(String)
        @species = Species.by_abbr(species[0...2])
        @job = Job.by_abbr(species[2..-1])
      else
        @species = species
        @job = job
      end
    end

    def abbr
      @abbr ||= @species.abbr + @job.abbr
    end

    def == (other)
      abbr == other.abbr
    end

    def eql?(other)
      self == other
    end

    def hash
      abbr.hash
    end

    def to_s
      abbr
    end

  private
    def self.read_combos
      @bad_combos, @good_combos =
        ComboReader.read_combos(Source.file_path('ng-restr.cc'))
    end
  end

  class ComboReader
    def self.read_combos(file)
      require 'crawl/source_reader'
      require 'crawl/job'
      require 'crawl/species'
      self.new(file).read
    end

    attr_reader :file
    def initialize(file)
      @file = file
    end

    def read
      current_job = nil
      species_slab = []

      bad_combos = Set.new
      good_combos = Set.new

      @available_species = Set.new

      scope = 0
      SourceReader.new(file, :collect => false, :start => %r/job_allowed/).lines { |line|

        scope += 1 if line =~ /\{/
        scope -= 1 if line =~ /\}/
        if line =~ /case JOB_(\w+)/ && scope == 2
          current_job = Job.by_name($1)
          @available_species = Set.new(Species.available_species)
          good_combos += combos(current_job)
        end

        if line =~ /SP_(\w+)/ && scope == 3
          sp = Species.by_name(Species.canonical_name($1))
          species_slab << sp
          @available_species.delete(sp)
        end

        if line =~ /cc_restricted/i
          combos = combos(current_job, species_slab)
          bad_combos += combos
          good_combos -= combos
        end

        if !species_slab.empty? && line =~ /CC_UNRESTRICTED/i
          good_combos = Set.new(combos(current_job, species_slab))
        end

        if !species_slab.empty? && line =~ /cc_banned/i && scope == 3
          good_combos -= combos(current_job, species_slab)
        end

        species_slab = [] if line =~ /cc_(banned|\w*?restrict)/i

        break if line =~ /default:/ && scope == 2
      }
      [bad_combos, good_combos]
    end

    def combos(job, species=nil)
      species = @available_species if !species || species.empty?
      species.map { |sp|
        Combo.new(sp, job)
      }
    end
  end
end
