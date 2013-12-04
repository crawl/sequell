require 'henzell/config'
require 'cmd/command'
require 'helper'

module Cmd
  class Options
    def initialize(options)
      @options = options
    end

    def [](key)
      @options[key]
    end

    def suppress_stderr
      self[:suppress_stderr]
    end

    def env
      self[:env]
    end

    def permitted_commands
      self[:permitted_commands]
    end

    def forbidden_commands
      self[:forbidden_commands]
    end

    def permitted?(command)
      (!permitted_commands ||
        permitted_commands.include?(command.command_name)) &&
      (!forbidden_commands ||
        !forbidden_commands.include?(command.command_name))
    end
  end

  class Executor
    def self.execute(command_line, options={})
      config = Henzell::Config.default
      command = Command.new(command_line)
      options = Options.new(options)
      unless command.valid?(config) && options.permitted?(command)
        raise StandardError, "Not a valid command: #{command}"
      end

      self.new(command, options, config).execute
    end

    def initialize(command, options, config)
      @command = command
      @options = options
      @config  = config
    end

    def execute
      @command.execute(@config, @options.env || Helper.henzell_env,
                       @options.suppress_stderr) || [1, '']
    end
  end
end
