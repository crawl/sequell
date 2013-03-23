#! /usr/bin/env ruby

require 'helper'

help("%CMD% <player> <monsters>: Will send <monsters> to <player>'s game (this is a campaign promise).")

begin
  args = ARGV[2].split()[1 .. -1]
  die "Usage: %CMD% <player> <monsters>" if args.size < 2

  puts "Sending #{args[1 .. -1].join(' ')} to #{args[0]}."
rescue
  puts $!
end
