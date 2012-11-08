require 'digest/sha1'
require 'fileutils'

module Graph
  class File
    GRAPH_OUTPUT_DIR = 'graphs'

    def initialize(title)
      @title = title
    end

    def filename
      @filename ||= make_filename
    end

    def graph_dir
      GRAPH_OUTPUT_DIR
    end

    def graph_filepath
      ::File.join(graph_dir, self.filename)
    end

    def with
      FileUtils.mkdir_p(graph_dir)
      ::File.open(graph_filepath, 'w') { |f|
        yield f
      }
    end

  private
    def make_filename
      Digest::SHA1.hexdigest(@title) + '.html'
    end
  end
end
