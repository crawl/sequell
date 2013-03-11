require 'cmd/user_command_db'
require 'cmd/user_def'
require 'cmd/command'

module Cmd
  class UserDefinedCommand
    def self.define(name, definition)
      Cmd::Command.assert_valid!(definition)
      cname = canonicalize_name(name)
      if Henzell::Config.default.commands.builtin?(cname)
        raise "Cannot redefine built-in command #{cname}"
      end
      existing_command = self.command(cname)
      UserCommandDb.db.define_command(canonicalize_name(name), definition)
      res = self.command(name)
      if existing_command
        puts("Redefined command: #{res}")
      else
        puts("Defined command: #{res}")
      end
      res
    end

    def self.commands
      UserCommandDb.db.commands.map { |name, definition|
        UserDef.new(name, definition)
      }
    end

    def self.expand(command_name)
      command = self.command(command_name)
      raise "No command: #{command_name}" unless command
      cmd = Cmd::Command.new(command.definition)
      [cmd.name, cmd.argument_string]
    end

    def self.each(&block)
      self.commands.each(&block)
    end

    def self.command(name)
      definition = UserCommandDb.db.query_command(canonicalize_name(name))
      return nil unless definition
      UserDef.new(definition[0], definition[1])
    end

    def self.delete(name)
      name = canonicalize_name(name)
      existing_command = self.command(name)
      raise "No command #{name}" if existing_command.nil?
      UserCommandDb.db.delete_command(name)
      existing_command
    end

    def self.canonicalize_name(name)
      name = name.downcase
      if name !~ /^[#{Regexp.quote(sigils)}]/
        name = "#{preferred_sigil}#{name}"
      end
      name
    end

    def self.sigils
      Henzell::Config.default[:sigils]
    end

    def self.preferred_sigil
      Henzell::Config.default[:preferred_sigil]
    end
  end
end
