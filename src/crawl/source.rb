module Crawl
  class MissingSourceFile < StandardError
    attr_reader :file

    def initialize(file)
      @file = file
      super("Cannot find #{file} in Crawl source tree")
    end
  end

  class Source
    SOURCE_ROOT = 'current'
    SOURCES_PATH = 'source'

    def self.crawl_executable
      file_path('crawl.build')
    end

    def self.file_path(filename)
      file = File.join(SOURCE_ROOT, SOURCES_PATH, filename)
      raise MissingSourceFile.new(file) unless File.exists?(file)
      file
    end
  end
end
