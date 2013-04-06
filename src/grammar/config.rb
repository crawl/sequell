require 'henzell/config'

module Grammar
  class Config
    CONFIG_FILE = 'config/grammar.yml'

    def self.config
      @config ||= YAML.load_file(Henzell::Config.file_path(CONFIG_FILE))
    end

    def self.option_names
      self['options']
    end

    def self.[](key)
      self.config[key]
    end

    def self.operators
      self['operators']
    end
  end
end
