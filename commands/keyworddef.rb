#! /usr/bin/env ruby

require 'helper'
require 'sqlhelper'
require 'cmd/user_keyword'

$ctx = CommandContext.new
$ctx.extract_options!('rm', 'ls')

def main
  show_help

  name = $ctx.shift!
  expansion = $ctx.argument_string

  if $ctx[:ls]
    list_keywords
  elsif $ctx[:rm] && name
    delete_keyword(name)
  elsif name && expansion.empty?
    display_keyword(name)
  elsif name && !expansion.empty?
    define_keyword(name, expansion)
  else
    show_help(true)
  end
rescue
  STDERR.puts("#$!: " + $!.backtrace.join("\n"))
  puts $!
end

def list_keywords
  keywords = Cmd::UserKeyword.keywords.map(&:name).sort
  if keywords.empty?
    puts "No user keywords"
  else
    puts("User keywords: " + keywords.join(", "))
  end
end

def delete_keyword(name)
  deleted_keyword = Cmd::UserKeyword.delete(name)
  puts("Deleted keyword: #{deleted_keyword}")
end

def display_keyword(name)
  keyword = Cmd::UserKeyword.keyword(name)
  if keyword.nil?
    begin
      parse = CTX_STONE.with do
        Query::QueryKeywordParser.parse(name)
      end
      kwtype =
        Cmd::UserKeyword.valid_keyword_name?(name) ? 'Built-in' :
                                                     'Keyword expression'
      puts "#{kwtype}: #{name} => #{parse.to_query_string}"
    rescue Query::KeywordParseError
      puts "No keyword '#{name}'"
    end
  else
    puts("Keyword: #{keyword}")
  end
end

def define_keyword(name, definition)
  Cmd::UserKeyword.define(name, definition)
end

def show_help(force=false)
  help(<<HELP, force)
Define keyword: `#{$ctx.command} <keyword> <definition>` to define,
`#{$ctx.command} -rm <keyword>` to delete, `#{$ctx.command} <keyword>` to query,
`#{$ctx.command} -ls` to list.
HELP
end

main
