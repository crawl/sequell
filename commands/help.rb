#! /usr/bin/env ruby

require 'helper'
require 'cmd/command'
require 'cmd/user_defined_command'
require 'henzell/config'

cmdline = ARGV[2].to_s.gsub(/^\S+\s+/, '').strip

STDERR.puts("ARGV: #{ARGV.inspect}")
help("!help [CMD] displays help on a command. For a list of commands, use `!cmdinfo` for built-ins, and `!cmd -ls` for user-defined commands.",
     cmdline.empty?)

def command_help(cmdline)
  cmd_words = cmdline.split(' ')
  cmd_words[0] = Cmd::UserDefinedCommand.canonicalize_name(cmd_words[0])
  cmd = Cmd::Command.new(cmd_words.join(' '))
  case
  when cmd.builtin?
    code, output = cmd.execute(Henzell::Config.default, Helper.henzell_env, false, true)
    puts("#{cmd.command}: #{output}")
  when cmd.user_defined?
    puts "[[[LEARNDB: #{cmd.command}: :::!help:#{cmd.command}:::No help for #{cmd.command} (you could add help with !learn add !help:#{cmd.command} <helpful text>)]]]"
  else
    puts "Unknown command: #{cmd}"
  end
end

command_help(cmdline)
