require 'yaml'
require 'henzell/config'

module Crawl
  class Config
    CONFIG_FILE = 'config/crawl-data.yml'

    def self.config_file
      Henzell::Config.file_path(CONFIG_FILE)
    end

    def self.config
      @config ||= read_config(config_file)
    end

    def self.[](key)
      self.config[key]
    end

  private
    def self.read_config(config_file)
      YAML.load_file(config_file)
    end
  end
end
