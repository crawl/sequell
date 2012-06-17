require 'henzell/commands'

module Henzell
  class Config
    CONFIG_FILE = 'henzell.rc'

    def self.read(cfg=CONFIG_FILE)
      config = self.new(cfg)
      config.load
      config
    end

    def initialize(cfg)
      @config_file = cfg
      @config = { }
    end

    def [](key)
      @config[key]
    end

    def commands
      @commands ||= Henzell::Commands.new(self[:commands_file])
    end

    def load
      File.open(@config_file, 'r') { |file|
        file.each { |line|
          next if line =~ /^\s*#/
          line = line.strip
          if line =~ /^(\w+)\s*=\s*(.*)/
            @config[$1.downcase.to_sym] = $2
          end
        }
      }
    end
  end
end
