#! /usr/bin/ruby

require 'commands/helper'
require 'set'

help("Maps a nick to name(s) used on cao. Usage: !nickmap <src> <dest1> <dest2> ...; !nickmap -rm <src>; !nickmap -rm . <dest>")

def cmd_nicks(cmdline)
  rm = cmdline.find { |a| a == '-rm' }
  cmdline.delete(rm) if rm

  if rm
    delete_nicks(cmdline)
  else
    add_nicks(cmdline[0], *cmdline[1 .. -1])
  end
end

def unique_nicks(str)
  nicks = str.split()

  nset = Set.new
  nicks = nicks.find_all do |n|
    dupe = nset.member?(n.downcase)
    nset.add(n.downcase)
    !dupe && n !~ /[ .*]/
  end

  res = nicks.join(" ")
  res.empty? ? nil : res
end

def add_nicks(from, *to)
  newnicks = unique_nicks((NICK_ALIASES[from] || '') + " " + to.join(" "))
  puts "Mapping #{from} = #{newnicks}"
  NICK_ALIASES[from.downcase] = newnicks
end

def delete_nicks(cmds)
  if not cmds.empty?
    delete_src(cmds[0])
    cmds[1 .. -1].each do |nick|
      delete_dest(nick)
    end
  end
end

def delete_src(nick)
  return if nick == '.'

  emap = NICK_ALIASES[nick.downcase]
  if emap && !emap.empty?
    puts "Deleting mapping #{nick} = #{emap}"
    NICK_ALIASES[nick.downcase] = nil
  end
end

def delete_dest(nick)
  todel = [ ]
  for k, v in nick.entries do
    todel << k if " #{v} " =~ / \Q#{nick}\E /i
  end
  todel.each do |n|
    delete_src(n)
  end
end

cmdline = ARGV[2].split()[1 .. -1]

if not cmdline.empty?
  load_nicks
  cmd_nicks(cmdline)
  save_nicks
end
