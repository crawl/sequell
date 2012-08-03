module Cmd
  class Command
    attr_reader :command_name
    attr_accessor :arguments

    def self.canonicalize_command_line(command_line)
      command_line.sub(/^(\?\?)(\S)/) { |match|
        ($1 + ' ' + $2)
      }
    end

    def initialize(command_line)
      command_line = self.class.canonicalize_command_line(command_line)
      @command_line = command_line
      @command_arguments = command_line.split(' ')
      @arguments = @command_arguments[1..-1]
      @command_name = nil
      @command_name = $1.downcase if command_line =~ /^(\S+)/
    end

    def command
      self.command_name
    end

    def argument_string
      @arguments.join(' ')
    end

    def to_s
      @command_line
    end

    def execute(config, default_nick)
      config.commands.execute(@command_line, default_nick)
    end

    def valid?(config)
      config.commands.include?(@command_name)
    end

    def to_s
      @command_line
    end
  end
end
