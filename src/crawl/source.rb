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
    SOURCES_PATH = 'crawl-ref/source'

    def self.file_path(filename)
      file = File.join(SOURCE_ROOT, SOURCES_PATH, filename)
      raise MissingSourceFile.new(file) unless File.exists?(file)
      file
    end
  end
end
