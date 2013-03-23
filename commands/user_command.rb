#! /usr/bin/env ruby

require 'helper'
require 'cmd/executor'

help("No help for user-defined commands")
puts Cmd::Executor.execute(ARGV[2], default_nick: ARGV[1],
                           forbidden_commands: ['??'])
