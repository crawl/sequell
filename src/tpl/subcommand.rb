require 'tpl/tplike'
require 'cmd/executor'
require 'command_context'
require 'helper'

module Tpl
  class Subcommand
    include Tplike

    attr_reader :command, :command_line
    def initialize(command, command_line)
      @command = command.to_s
      @command_line = command_line
    end

    def eval(provider)
      return self.to_s unless Template.allow_subcommands?
      Cmd::Executor.execute_subcommand(self.eval_command_line(provider))
    end

    def eval_command_line(provider)
      @command + @command_line.eval(provider).to_s
    end

    def full_command_line
      "#{@command}#{@command_line}"
    end

    def to_s
      "$(#{full_command_line})"
    end
  end
end
