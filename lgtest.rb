#! /usr/bin/env ruby

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
