#! /usr/bin/env ruby

require 'helper'
require 'sqlhelper'
require 'tpl/function_defs'

$ctx = CommandContext.new
$ctx.extract_options!('rm', 'ls')

def main
  show_help

  name = $ctx.shift!
  expansion = $ctx.argument_string

  if $ctx[:ls]
    list_functions
  elsif $ctx[:rm] && name
    forbid_private_messaging! "Cannot delete functions in PM."
    delete_function(name)
  elsif name && expansion.empty?
    display_function(name)
  elsif name && !expansion.empty?
    forbid_private_messaging! "Cannot define functions in PM."
    define_function(name, expansion)
  else
    show_help(true)
  end
rescue
  puts $!
  raise
end

def list_functions
  functions = Cmd::UserFunction.functions.map(&:name).sort
  if functions.empty?
    puts "No user functions"
  else
    puts("User functions: " + functions.join(", "))
  end
end

def delete_function(name)
  deleted_function = Cmd::UserFunction.delete(name)
  puts("Deleted function: #{deleted_function}")
end

def display_function(name)
  function = Cmd::UserFunction.function(name)
  if function.nil?
    puts "No user function '#{name}'"
  else
    puts("#{function}")
  end
end

def define_function(name, definition)
  Cmd::UserFunction.define(name, definition)
end

def show_help(force=false)
  help(<<HELP, force)
Define function: `#{$ctx.command} <name> <definition>` to define,
`#{$ctx.command} -rm <name>` to delete, `#{$ctx.command} <name>` to query,
`#{$ctx.command} -ls` to list.
HELP
end

main
