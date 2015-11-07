#! /usr/bin/env ruby

require 'helper'
require 'cmd/executor'
require 'timeout'

help("No help for user-defined commands")

TIME_LIMIT = 90

cmd = ARGV[2]
begin
  Timeout.timeout(TIME_LIMIT) {
    exit_code, output = Cmd::Executor.execute(cmd,
      env: Helper.henzell_env.merge(
        'nick' => ARGV[1],
        'user' => ARGV[1]
      ),
      forbidden_commands: ['??'])

    puts(output)
    exit(exit_code)
  }
rescue Timeout::Error
  puts "#{TIME_LIMIT}s limit exceeded: killed #{cmd}"
  raise
rescue StandardError
  puts $!
  raise
end
