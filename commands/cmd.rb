#! /usr/bin/env ruby

require 'helper'
require 'irc_auth'
require 'cmd/user_defined_command'

$ctx = CommandContext.new
$ctx.extract_options!('rm', 'ls')

def cname(name)
  Cmd::UserDefinedCommand.canonicalize_name(name)
end

def main
  show_help

  name = $ctx.shift!
  command = $ctx.argument_string

  if $ctx[:ls]
    list_user_commands
  elsif $ctx[:rm] && name
    IrcAuth.authorize!('cmd:' + cname(name))
    delete_user_command(name)
  elsif name && command.empty?
    display_user_command(name)
  elsif name && !command.empty?
    IrcAuth.authorize!('cmd:' + cname(name))
    define_user_command(name, command)
  else
    show_help(true)
  end
rescue
  STDERR.puts("#$!: " + $!.backtrace.join("\n"))
  puts $!
end

def list_user_commands
  commands = Cmd::UserDefinedCommand.commands.map(&:name).sort
  if commands.empty?
    puts "No user commands"
  else
    puts("User Commands: " + commands.join(", "))
  end
end

def delete_user_command(name)
  deleted_command = Cmd::UserDefinedCommand.delete(name)
  puts("Deleted command: #{deleted_command}")
end

def display_user_command(name)
  command = Cmd::UserDefinedCommand.command(name)
  if command.nil?
    name = cname(name)
    definition = Henzell::Config.default.commands.definition(name)
    if definition
      puts("Built-in: #{name} => #{command_source_url(definition)}")
    else
      puts("No command #{name}")
    end
  else
    puts("Command: #{command}")
  end
end

def command_source_url(definition)
  Henzell::Config.source_repository_url("commands/#{definition}")
end

def define_user_command(name, definition)
  definition = definition.sub(/^\s*=>\s*/, '')
  Cmd::UserDefinedCommand.define(name, definition)
end

def show_help(force=false)
  help(<<HELP, force)
Define custom command: `#{$ctx.command} <name> <command-line>` to define,
`#{$ctx.command} -rm <name>` to delete, `#{$ctx.command} <name>` to query,
`#{$ctx.command} -ls` to list.
HELP
end

main
