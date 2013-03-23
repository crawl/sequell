require 'crawl/config'

module Crawl
  class Job
    def self.by_name(name)
      self.new(canonical_name(name))
    end

    def self.by_abbr(abbr)
      self.by_name(job_abbr_name_map[abbr])
    end

    def self.canonical_name(name)
      name.downcase.tr('_', ' ').gsub(/\b([a-z])/) { |match|
        $1.upcase
      }
    end

    def self.available_jobs
      require 'crawl/source'
      @available_jobs ||=
        JobReader.read_jobs(Source.file_path('enum.h')).map { |name|
          self.new(name)
        }
    end

    def self.job_abbr_name_map
      @job_abbr_name_map ||= Hash[ Config['classes'].map { |abbr, job|
        [abbr, job.sub('*', '')]
      } ]
    end

    def self.job_name_abbr_map
      @job_name_abbr_map ||= job_abbr_name_map.invert
    end

    attr_reader :name
    def initialize(name)
      @name = name
    end

    def abbr
      @abbr ||= Job.job_name_abbr_map[@name]
    end

    def == (other)
      @name == other.name
    end

    def eql?(other)
      self == other
    end

    def hash
      @name.hash
    end

    def to_s
      @name
    end
  end

  class JobReader
    def self.read_jobs(file)
      require 'crawl/source_reader'

      SourceReader.new(file, :start => %r/^enum\s+job_type/,
        :end => %r/NUM_JOBS/).lines { |line|
        Job.canonical_name($1) if line =~ /JOB_(\w+)/
      }
    end
  end
end
