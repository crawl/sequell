require 'yaml'

module Crawl
  class Config
    CONFIG_FILE = 'config/crawl-data.yml'

    def self.config
      @config ||= read_config
    end

    def self.[](key)
      self.config[key]
    end

  private
    def self.read_config
      YAML.load_file(CONFIG_FILE)
    end
  end
end
