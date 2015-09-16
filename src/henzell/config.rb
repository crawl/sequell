require 'yaml'
require 'pathname'

module Henzell
  class Config
    DEFAULTS_FILEPATH = 'rc/sequell.defaults'
    CONFIG_FILEPATH = 'rc/sequell.rc'
    SOURCE_BROWSE_URL = 'https://github.com/crawl/sequell/blob/master'

    def self.root
      ENV['HENZELL_ROOT'] || '.'
    end

    def self.root_relative_path(file)
      path = Pathname.new(file)
      unless path.relative?
        path = path.relative_path_from(Pathname.new(self.root))
      end
      path.to_s
    end

    def self.source_repository_url(file, line=nil)
      file_url = "#{SOURCE_BROWSE_URL}/#{root_relative_path(file)}"
      return "#{file_url}\#L#{line}" if line
      file_url
    end

    def self.file_path(name)
      File.join(self.root, name)
    end

    def self.defaults_file
      file_path(DEFAULTS_FILEPATH)
    end

    def self.config_file
      file_path(CONFIG_FILEPATH)
    end

    def self.default
      @default ||= self.read
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

    def commands_files
      if ENV['HENZELL_ALL_COMMANDS']
        Dir[Henzell::Config.file_path('config/commands*.txt')]
      else
        Henzell::Config.file_path(self[:commands_file])
      end
    end

    def commands
      require 'henzell/commands'

      @commands ||= Henzell::Commands.new(self.commands_files)
    end

    def load
      @defaults = YAML.load_file(self.class.defaults_file)
      @config = @defaults.merge(YAML.load_file(@config_file))
    end
  end
end
