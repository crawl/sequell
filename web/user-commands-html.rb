#! /usr/bin/env ruby

$LOAD_PATH << 'src'

require 'cmd/user_command_db'
require 'haml'

TEMPLATE = 'web/user-defined.html.haml'

db = Cmd::UserCommandDb.db
keywords = db.keywords
commands = db.commands
functions = db.functions

puts Haml::Engine.new(File.read(TEMPLATE)).render(
  Object.new,
  keywords: keywords, commands: commands, functions: functions)
