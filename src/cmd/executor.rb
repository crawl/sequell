require 'henzell/config'
require 'cmd/command'
require 'command_context'
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

  class UnknownCommandError < StandardError
    attr_reader :command, :command_line

    def initialize(command, command_line)
      super("Not a valid command: #{command} in #{command_line}")
      @command = command
      @command_line = command_line
    end
  end

  class Executor
    @@default_env = nil
    def self.with_default_env(env)
      old_env = @@default_env
      @@default_env = env
      begin
        yield
      ensure
        @@default_env = old_env
      end
    end

    def self.default_env
      @@default_env
    end

    def self.execute_subcommand(command_line)
      CommandContext.subcommand_context {
        debug { "Evaluating subcommand: '#{command_line}'" }
        exec = self.execute(
          command_line,
          forbidden_commands: ['??'],
          suppress_stderr: true)
        report_subcommand_error(command_line, exec[1]) unless exec[0] == 0
        (exec[1] || '').strip
      }
    end

    def self.report_subcommand_error(command_line, err)
      err ||= ''
      raise err if err =~ /^\[\[\[/
      raise StandardError.new("Subcommand $(#{command_line}) failed: " +
        (err || '').strip)
    end

    def self.execute(command_line, options={})
      config = Henzell::Config.default
      command = Command.new(command_line)
      options = Options.new({ env: self.default_env }.merge(options))
      unless command.valid?(config) && options.permitted?(command)
        raise UnknownCommandError.new(command, command_line)
      end

      self.with_default_env(options.env) {
        self.new(command, options, config).execute
      }
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
