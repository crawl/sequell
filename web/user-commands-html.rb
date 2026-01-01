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

def term_defs(pattern)
  ldb = LearnDB::DB.default
  ldb.terms_matching(pattern).map { |term|
    e = ldb.entry(term)
    [e.name, e.definitions.join(' ')]
  }
end

tries = 10
while tries > 0
  begin
    keywords = db.keywords
    ldb = LearnDB::DB.default
    commands = db.commands.map { |c|
      [c[0], c[1], ldb.entry("!help:#{c[0]}").definitions[0]]
    }.sort { |a, b|
      if !a[2] != !b[2]
        if a[2]
          -1
        else
          1
        end
      else
        a[0] <=> b[0]
      end
    }
    functions = db.functions
    behaviours = ldb.entry(':beh:').definitions
    acls = term_defs(/^:acl:.*/).sort { |a, b|
      lencomp = b[0].size <=> a[0].size
      lencomp != 0 ? lencomp : a[0] <=> b[0]
    }
    groups = term_defs(/^:group:.*/)

    puts Haml::Engine.new(File.read(TEMPLATE)).render(
      Object.new,
      keywords: keywords,
      commands: commands,
      functions: functions,
      acls: acls,
      groups: groups,
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
