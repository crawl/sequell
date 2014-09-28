#! /usr/bin/env ruby

require 'helper'

require 'set'
require 'irc_auth'
require 'sqlhelper'
require 'nick/db'
require 'nick/entry'
require 'query/listgame_parser'

args = ARGV[2]
cmdline = args.split()[1 .. -1].map { |x| x.downcase }

help("Maps a nick to name(s) used on the public servers. Usage: %CMD% <src> <dest1> <dest2> ...; %CMD% -rm <src>; %CMD% -rm <src> <dest>",
  cmdline.empty?)

def cmd_nicks(cmdline)
  rm = cmdline.find { |a| a == '-rm' }
  cmdline.delete(rm) if rm

  if rm
    forbid_private_messaging! "Cannot delete nicks in PM."
    IrcAuth.authorize!(:any)
    delete_nicks(cmdline)
  else
    add_nicks(cmdline.join(' '))
  end
end

def add_nicks(mapping_string)
  mapping_string = mapping_string.sub('=>', ' ').strip
  parsed_nick = Nick::Entry.parse(mapping_string)

  if !parsed_nick || parsed_nick.nick == '.' || parsed_nick == '*'
    die "Bad nick mapping #{mapping_string}"
  end

  if !parsed_nick.empty?
    forbid_private_messaging! "Cannot add nicks in PM."
    IrcAuth.authorize!(:any)
  end

  if parsed_nick.has_condition?
    begin
      cond = parsed_nick.listgame_conditions
      Query::ListgameParser.fragment(cond)
    rescue => e
      STDERR.puts(e, e.backtrace.join("\n"))
      raise "Invalid nick condition '#{cond}': #{e}"
    end
  end

  old_nick = NickDB[parsed_nick.nick].dup
  nick = NickDB.append_nick(parsed_nick)
  if !nick.stub?
    puts "Mapping #{nick}"
  else
    if !parsed_nick.empty? && !old_nick.stub?
      puts "Deleted #{old_nick}"
    else
      puts "No nick mapping for #{parsed_nick.nick}."
    end
  end
  !parsed_nick.empty?
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
  !cmds.empty?
end

def die_no_nick(nick)
  die "No nick mapping for #{nick}."
end

def delete_src(nick)
  deleted = NickDB.delete(nick)
  die_no_nick(nick) if deleted.stub?
  puts "Deleted #{deleted}"
end

def delete_dest_from(key, value)
  nick = NickDB[key]
  die_no_nick(key) if nick.stub?

  description = nick.to_s
  removed = nick.delete(value)
  if !removed
    puts "#{value} not mapped in #{description}"
  elsif removed
    if nick.stub?
      puts "Deleted #{description}"
    else
      puts "Deleted #{value} from #{description}"
    end
  end
end

begin
  if not cmdline.empty?
    changed = cmd_nicks(cmdline)
    NickDB.save! if changed
  end
rescue
  puts $!
  raise
end
