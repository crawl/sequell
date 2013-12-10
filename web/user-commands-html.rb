#! /usr/bin/env ruby

$LOAD_PATH << 'src'

require 'cmd/user_command_db'
require 'learndb'
require 'haml'
require 'cgi'

TEMPLATE = 'web/user-defined.html.haml'

def h(text)
  CGI.escapeHTML(text)
end

db = Cmd::UserCommandDb.db

tries = 10
while tries > 0
  begin
    keywords = db.keywords
    commands = db.commands
    functions = db.functions
    behaviours = LearnDB::DB.default.entry(':beh:').definitions

    puts Haml::Engine.new(File.read(TEMPLATE)).render(
      Object.new,
      keywords: keywords,
      commands: commands,
      functions: functions,
      behaviours: behaviours.map { |x|
        res = x.split(':::')
        res.unshift(nil) if res.size == 1
        res
      })

    break
  rescue SQLite3::BusyException
    sleep 1
    tries -= 1
  end
end
