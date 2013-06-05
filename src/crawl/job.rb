require 'crawl/config'
require 'set'

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

    def self.class_map
      Config['classes']
    end

    def self.lower_class_name_set
      @lower_class_name_set ||=
        Set.new(class_map.values.map(&:as_array).flatten.map(&:downcase).map {
          |c|
          c.gsub('*', '')
        }.map(&:strip))
    end

    def self.job_exists?(cls)
      return false unless cls
      lower_class_name_set.include?(cls.downcase.gsub('_', ' ').strip)
    end

    def self.dead_jobs
      @dead_jobs ||=
        class_map.values.select { |x| x.index('*') }.map { |x| x.gsub('*', '') }.
        map { |x| self.new(x) }
    end

    def self.dead_job_names
      @dead_job_names ||= Set.new(self.dead_jobs.map(&:name))
    end

    def self.dead_job?(job_name)
      self.dead_job_names.include?(job_name)
    end

    def self.available_jobs
      require 'crawl/source'
      @available_jobs ||=
        JobReader.read_jobs(Source.file_path('enum.h')).map { |name|
          self.new(name)
        } - dead_jobs
    end

    def self.job_abbr_name_map
      @job_abbr_name_map ||= Hash[ class_map.map { |abbr, job|
        [abbr, job.as_array.first.sub('*', '')]
      } ]
    end

    def self.job_name_abbr_map
      @job_name_abbr_map ||= job_abbr_name_map.invert
    end

    attr_reader :name
    def initialize(name)
      @name = name
    end

    def dead?
      self.class.dead_job?(self.name)
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
      @job ||= @name.hash
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
