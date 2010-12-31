#! /usr/bin/env ruby

ENV['HENZELL_SQL_QUERIES'] = 'y'
CMD = ARGV[0] || 'listgame.rb'
while true
  print "!lg: "
  a = STDIN.gets
  break unless a
  cmd = "!lg " + a.chomp
  puts cmd
  system "./commands/#{CMD} '' 'greensnark' '#{cmd}'"
  puts
end
