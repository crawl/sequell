require 'crawl/config'

module Crawl
  class Species
    def self.by_name(name)
      self.new(canonical_name(name, false))
    end

    def self.by_abbr(abbr)
      self.by_name(species_abbr_name_map[abbr])
    end

    def self.canonical_name(name, fold_grouped_species=true)
      if fold_grouped_species && name =~ /draconian/i
        return 'Draconian'
      end
      name.downcase.tr('_', ' ').gsub(/\b([a-z])/) { |match|
        $1.upcase
      }
    end

    def self.species_map
      Config['species']
    end

    def self.dead_species
      species_map.values.select { |x| x.index('*') }.map { |x| x.gsub('*', '') }.
        map { |x| self.new(x) }
    end

    def self.available_species
      @available_species =
        read_available_species - dead_species
    end

    def self.species_abbr_name_map
      @species_abbr_name_map ||= Hash[ Config['species'].map { |abbr, sp|
        [abbr, sp.sub('*', '')]
      } ]
    end

    def self.species_name_abbr_map
      @species_name_abbr_map ||= species_abbr_name_map.invert
    end

    attr_reader :name

    def initialize(name)
      @name = name
    end

    def abbr
      @abbr ||= Species.species_name_abbr_map[@name]
    end

    def == (other)
      @name == other.name
    end

    def eql?(other)
      self == other
    end

    def hash
      @hash ||= @name.hash
    end

    def to_s
      @name
    end

  private
    def self.read_available_species
      require 'crawl/source'
      SpeciesReader.read_species(Source.file_path('enum.h')).map { |sp|
        Species.new(sp)
      }
    end
  end

  class SpeciesReader
    def self.read_species(file)
      require 'crawl/source_reader'
      SourceReader.new(
        file,
        :start => %r/^\s*enum\s+species_type/,
        :end => %r/placeholder/).lines { |line|
        Species.canonical_name($1) if line !~ /placeholder/ && line =~ /SP_(\w+)/
      }
    end
  end
end
