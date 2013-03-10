#! /usr/bin/env ruby

require 'helper'
require 'cmd/user_defined_command'

$ctx = CommandContext.new
$ctx.extract_options!('rm', 'ls')

def main
  show_help

  name = $ctx.shift!
  command = $ctx.argument_string

  if $ctx[:ls]
    list_user_commands
  elsif $ctx[:rm] && name
    delete_user_command(name)
  elsif name && command.empty?
    display_user_command(name)
  elsif name && !command.empty?
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
    puts("No command #{name}")
  else
    puts("Command: #{command}")
  end
end

def define_user_command(name, definition)
  command = Cmd::UserDefinedCommand.define(name, definition)
  puts("Defined command: #{command}")
end

def show_help(force=false)
  help(<<HELP, force)
Define custom command: `#{$ctx.command} <name> <command-line>` to define,
`#{$ctx.command} -rm <name> to delete, `#{$ctx.command} <name>` to query,
`#{$ctx.command} -list` to list.
HELP
end

main
