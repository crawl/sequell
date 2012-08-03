require 'henzell/learndb_query'

module Henzell
  class Commands
    def initialize(commands_file)
      @commands_file = commands_file
      @commands = { }
      self.load
    end

    def include?(command_name)
      @commands[command_name] || command_name == '??'
    end

    def learndb_query(arguments)
      [0, Henzell::LearnDBQuery.query(arguments), '']
    end

    def execute(command_line, default_nick='???')
      unless command_line =~ /^(\S+)\s+(.*)/
        raise StandardError, "Bad command line: #{command_line}"
      end
      command = $1.downcase
      arguments = $2

      if command == '??'
        return learndb_query(arguments)
      end

      unless self.include?(command)
        raise StandardError, "Bad command: #{command_line}"
      end

      command_script = "./commands/" + @commands[command]
      target = default_nick
      if command_line =~ /^(\S+)\s+(\S+)/
        target = $2
      end
      system_command_line =
        %{#{command_script} #{quote(target)} #{quote(default_nick)} } +
        %{#{quote(command_line)} ''}
      STDERR.puts("Executing #{system_command_line}")
      output = %x{#{system_command_line}}
      exit_code = $? >> 8
      [exit_code, output, system_command_line]
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
          if line =~ /^(\S+) (.*)/
            @commands[$1.downcase] = $2
          end
        }
      }
    end
  end
end
