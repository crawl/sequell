#! /usr/bin/env ruby

require 'helper'
require 'cmd/executor'
require 'timeout'

help("No help for user-defined commands")

TIME_LIMIT = 45

begin
  Timeout.timeout(TIME_LIMIT) {
    exit_code, output = Cmd::Executor.execute(ARGV[2], default_nick: ARGV[1],
      forbidden_commands: ['??'])

    puts(output)
    exit(exit_code)
  }
rescue Timeout::Error => e
  puts "Time limit of #{TIME_LIMIT}s exceeded"
  raise
rescue StandardError
  puts $!
  raise
end
