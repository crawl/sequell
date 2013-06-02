require 'henzell/learndb_query'
require 'query/grammar'
require 'set'
require 'cmd/user_defined_command'
require 'query/query_string_template'
require 'json'

module Henzell
  class Commands
    def initialize(commands_file)
      @commands_file = commands_file
      @user_commands = { }
      @commands = { }
      self.load
    end

    def to_s
      "Commands[builtin:#{@commands.keys.sort}, " +
        "user:#{@user_commands.keys.sort}]"
    end

    def builtin?(command_name)
      @commands[command_name] || command_name == '??'
    end

    def user_defined?(command_name)
      @user_commands[command_name]
    end

    def include?(command_name)
      builtin?(command_name) || user_defined?(command_name)
    end

    def learndb_query(arguments)
      [0, Henzell::LearnDBQuery.query(arguments), '']
    end

    def execute(command_line, default_nick='???', suppress_stderr=false)
      unless command_line =~ /^(\S+)(?:(\s+(.*)))?/
        raise StandardError, "Bad command line: #{command_line}"
      end
      command = $1.downcase
      arguments = ($2 || '').strip

      if command == '??'
        return learndb_query(arguments)
      end

      execute_command(command, arguments, default_nick, suppress_stderr)
    end

    def direct_command?(command)
      (@commands[command] || { })[:direct]
    end

    def echo?(command)
      (@commands[command] || { })[:file] =~ /echo.pl/
    end

    def execute_command(command, arguments, default_nick, suppress_stderr=false)
      seen_commands = Set.new

      unless direct_command?(command)
        arguments = Query::QueryStringTemplate.substitute(arguments, [''],
          default_nick)
        arguments = arguments.join(' ') if arguments.is_a?(Array)
      end

      while true
        if seen_commands.include?(command)
          raise "Bad command (recursive): #{command}"
        end

        seen_commands << command
        unless self.include?(command)
          raise StandardError, "Bad command: #{command} #{arguments}"
        end

        if self.user_defined?(command)
          old_command = command
          old_arguments = arguments
          command, args = Cmd::UserDefinedCommand.expand(command)
          unless ENV['HENZELL_TEST']
            STDERR.puts("Expanded #{old_command} => #{command} #{args}")
          end
          arguments =
            Query::QueryStringTemplate.substitute(args, [arguments], default_nick)
          arguments = arguments.join(' ') if arguments.is_a?(Array)
          unless ENV['HENZELL_TEST']
            STDERR.puts("Expanded #{args} with #{old_arguments} => #{arguments}")
          end
          next
        end

        command_script =
          File.join(Config.root, "commands", @commands[command][:file])
        target = default_nick

        command_line = [command, arguments].join(' ')
        unless ENV['HENZELL_TEST']
          STDERR.puts("Cmd: " + command_line)
        end

        if echo?(command)
          debug{"Echo: #{arguments}"}
          arguments = arguments.join(' ') if arguments.is_a?(Array)
          return [0, arguments.to_s]
        else
          redirect = suppress_stderr ? '2>/dev/null' : ''
          system_command_line =
            %{#{command_script} #{quote(target)} #{quote(default_nick)} } +
            %{#{quote(command_line)} '' #{redirect}}
          File.open('cmd.log', 'a') { |f|
            f.puts("Executing: #{system_command_line}")
          }
          output = %x{#{system_command_line}}
          exit_code = $? >> 8
          return [exit_code, output, system_command_line]
        end
      end
    end

    def quote(text)
      text.gsub(/[^\w]/) { |t|
        '\\' + t
      }
    end

    def load
      File.open(@commands_file, 'r') { |file|
        file.each { |line|
          line = line.strip
          next if line =~ /^#/
          if line =~ /^(\S+) (\S+)(?:\s+(:direct))?\s*$/
            @commands[$1.downcase] = { file: $2, direct: $3 }
          end
        }
      }

      Cmd::UserDefinedCommand.each { |command|
        @user_commands[command.name] = command
      }
    end
  end
end
