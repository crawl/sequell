require 'henzell/commands'

module Henzell
  class Config
    CONFIG_FILEPATH = 'rc/henzell.rc'

    def self.root
      ENV['HENZELL_ROOT'] || '.'
    end

    def self.file_path(name)
      File.join(self.root, name)
    end

    def self.config_file
      file_path(CONFIG_FILEPATH)
    end

    def self.read(cfg=self.config_file)
      config = self.new(cfg)
      config.load
      config
    end

    def initialize(cfg)
      @config_file = cfg
      @config = { }
    end

    def [](key)
      @config[key.to_s]
    end

    def commands
      @commands ||= Henzell::Commands.new(
        Henzell::Config.file_path(self[:commands_file]))
    end

    def load
      @config = YAML.load_file(@config_file)
    end
  end
end
