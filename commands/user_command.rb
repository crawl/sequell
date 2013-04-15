#! /usr/bin/env ruby

require 'helper'
require 'cmd/executor'

help("No help for user-defined commands")

begin
  exit_code, output = Cmd::Executor.execute(ARGV[2], default_nick: ARGV[1],
    forbidden_commands: ['??'])

  puts(output)
  exit(exit_code)
rescue StandardError
  puts $!
  raise
end
