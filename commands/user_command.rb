#! /usr/bin/env ruby

require 'helper'
require 'cmd/executor'
require 'timeout'

help("No help for user-defined commands")

TIME_LIMIT = 60

begin
  Timeout.timeout(TIME_LIMIT) {
    exit_code, output = Cmd::Executor.execute(ARGV[2],
      env: {
        'nick' => ARGV[1],
        'user' => ARGV[1],
      }.merge(Helper.henzell_env),
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
