#! /usr/bin/ruby

require 'commands/helper'
require 'set'

if ENV['PRIVMSG'] == 'y'
  puts "Cannot map nicks on PM."
  exit 1
end

help("Maps a nick to name(s) used on cao. Usage: %CMD% <src> <dest1> <dest2> ...; %CMD% -rm <src>; %CMD% -rm . <dest>")

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
  NICK_ALIASES[from.downcase] = newnicks
  puts "Mapping " + nickmap_string(from)
end

def delete_nicks(cmds)
  if not cmds.empty?
    if cmds.size == 1 then
      delete_src(cmds[0])
    else
      cmds[1 .. -1].each do |nick|
        delete_dest_from(cmds[0], nick)
      end
    end
  end
end

def delete_src(nick)
  return if nick == '.'

  emap = NICK_ALIASES[nick.downcase]
  if emap && !emap.empty?
    puts "Deleted #{nickmap_string(nick)}"
    NICK_ALIASES[nick.downcase] = nil
  end
end

def nickmap_string(key)
  mapped_nicks = NICK_ALIASES[key]
  if !mapped_nicks || mapped_nicks.empty?
    return nil
  else
    "#{key} => #{mapped_nicks}"
  end
end

def delete_dest_from(key, value)
  emap = NICK_ALIASES[key.downcase]
  mapping_desc = nickmap_string(key)
  emap = emap.split
  emap.delete(value) if emap
  if emap && !emap.empty?
    NICK_ALIASES[key.downcase] = emap.join(' ')
    puts "Deleted #{value} from #{mapping_desc}"
  else
    NICK_ALIASES[key.downcase] = nil
    puts "Deleted #{mapping_desc}"
  end
end

args = ARGV[2].gsub("/", "").gsub("\\", "")
cmdline = args.split()[1 .. -1]

if not cmdline.empty?
  load_nicks
  cmd_nicks(cmdline)
  save_nicks
end
