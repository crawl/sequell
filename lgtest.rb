#! /usr/bin/ruby

while true
  print "!lg: "
  a = STDIN.gets
  break unless a
  cmd = "!lg " + a.chomp
  puts cmd
  system "./commands/listgame.rb '' 'greensnark' '#{cmd}'"
  puts
end
