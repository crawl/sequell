require 'henzell/config'

module Cmd
  class Command
    attr_reader :command_name

    def initialize(config, command_line)
      @config = config
      @command_line = command_line
      @command_name = nil
      @command_name = $1.downcase if command_line =~ /^(\S+)/
    end

    def execute(default_nick)
      @config.commands.execute(@command_line, default_nick)
    end

    def valid?
      @config.commands.include?(@command_name)
    end

    def to_s
      @command_line
    end
  end

  class Options
    def initialize(options)
      @options = options
    end

    def [](key)
      @options[key]
    end

    def default_nick
      self[:default_nick]
    end

    def permitted_commands
      self[:permitted_commands]
    end

    def permitted?(command)
      !permitted_commands || permitted_commands.include?(command.command_name)
    end
  end

  class Executor
    def self.execute(command_line, options={})
      config = Henzell::Config.read
      command = Command.new(config, command_line)
      options = Options.new(options)
      unless command.valid? && options.permitted?(command)
        raise StandardError, "Not a valid command: #{command}"
      end

      self.new(command, options).execute
    end

    def initialize(command, options)
      @command = command
      @options = options
    end

    def execute
      @command.execute(@options.default_nick || '???')[1] || 'ERROR'
    end
  end
end
