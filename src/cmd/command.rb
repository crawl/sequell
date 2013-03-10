module Cmd
  class Command
    attr_reader :command_name
    attr_accessor :arguments

    def self.commands
      Henzell::Config.default.commands
    end

    def self.assert_valid!(command_line)
      seen_expansions = { }
      cmd = self.new(command_line)
      while true
        unless self.commands.include?(cmd.command)
          raise "Unknown command: #{cmd}"
        end
        return true if self.commands.builtin?(cmd.command)
        if seen_expansions[cmd.command]
          raise "Recursive command expansion in #{command_line}"
        end
        seen_expansions[cmd.command] = true
        cmd, extra_args = Cmd::UserDefinedCommand.expand(cmd.command)
        cmd = self.new(cmd + " " + extra_args)
      end
    end

    def self.canonicalize_command_line(command_line)
      command_line.sub(/^(\?\?)(\S)/) { |match|
        ($1 + ' ' + $2)
      }.sub(/^\?\? (.*)/, '!learn query \1')
    end

    def initialize(command_line)
      command_line = self.class.canonicalize_command_line(command_line)
      @command_line = command_line
      @command_arguments = command_line.split(' ')
      @arguments = @command_arguments[1..-1]
      @command_name = nil
      @command_name = $1.downcase if command_line =~ /^(\S+)/
      if learndb_query?
        @command_name = '??'
        @arguments.shift
      end
    end

    alias :command :command_name
    alias :name :command

    def learndb_query?
      @command_line =~ /^!learn query/
    end

    def argument_string
      @arguments.join(' ')
    end

    def first
      @arguments.first
    end

    def rest
      @arguments[1..-1].join(' ')
    end

    def command_line
      if learndb_query?
        "?? #{argument_string}"
      else
        @command_line
      end
    end

    def to_s
      self.command_line
    end

    def execute(config, default_nick)
      config.commands.execute(self.command_line, default_nick)
    end

    def valid?(config)
      config.commands.include?(@command_name)
    end
  end
end
