#! /usr/bin/env ruby

require 'helper'
require 'sqlhelper'
require 'irc_auth'
require 'cmd/user_keyword'
require 'query/listgame_parser'
require 'query/ast/ast_fixup'

$ctx = CommandContext.new
$ctx.extract_options!('rm', 'ls')

def main
  show_help

  name = $ctx.shift!
  expansion = $ctx.argument_string

  if $ctx[:ls]
    list_keywords
  elsif $ctx[:rm] && name
    IrcAuth.authorize!('kw:' + name.downcase)
    delete_keyword(name)
  elsif name && expansion.empty?
    display_keyword(name)
  elsif name && !expansion.empty?
    IrcAuth.authorize!('kw:' + name.downcase)
    define_keyword(name, expansion)
  else
    show_help(true)
  end
rescue
  puts $!
  raise
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
        Query::AST::ASTFixup.result(
          Query::ListgameParser.fragment(name), true)
      end
      kwtype =
        Cmd::UserKeyword.valid_keyword_name?(name) ? 'Built-in' :
                                                     'Expression'
      if parse.nil?
        puts "#{kwtype}: #{name} evaluates as nothing."
      else
        puts "#{kwtype}: #{name} => #{parse.to_query_string(false)}"
      end
    rescue Query::KeywordParseError
      puts "No keyword '#{name}'"
      raise
    end
  else
    puts("Keyword: #{keyword}")
  end
end

def define_keyword(name, definition)
  definition = definition.sub(/^\s*=>\s*/, '')
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
