require 'tpl/tplike'
require 'cmd/executor'
require 'command_context'

module Tpl
  class Subcommand
    include Tplike

    def initialize(command, command_line)
      @command = command
      @command_line = command_line
    end

    def eval(provider)
      return self.to_s unless Template.allow_subcommands?
      CommandContext.subcommand_context {
        exec = Cmd::Executor.execute(
          self.full_command_line,
          default_nick: CommandContext.default_nick,
          forbidden_commands: ['??'],
          suppress_stderr: true)
        raise StandardError.new("Subcommand #{self} failed: " +
                                (exec[1] || '').strip) unless exec[0] == 0
        (exec[1] || '').strip
      }
    end

    def full_command_line
      "#{@command}#{@command_line}"
    end

    def to_s
      "$(#{full_command_line})"
    end
  end
end
