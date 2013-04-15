require 'parslet'

require 'tpl/fragment'
require 'tpl/text_fragment'
require 'tpl/lookup_fragment'
require 'tpl/substitution'
require 'tpl/gsub'
require 'tpl/subcommand'
require 'tpl/funcall'

module Tpl
  class TemplateBuilder < Parslet::Transform
    rule(tpl: simple(:tpl)) {
      tpl.collapse
    }
    rule(tpl: sequence(:fragments)) {
      Fragment.new(*fragments).collapse
    }
    rule(char: simple(:c)) { c.to_s }
    rule(leftquot: simple(:c)) { c.to_s }
    rule(rightquot: simple(:c)) { c.to_s }

    rule(text: sequence(:c)) { TextFragment.new(c.join('')) }
    rule(raw: simple(:raw)) {
      TextFragment.new(raw.to_s)
    }
    rule(template: simple(:template),
         text: sequence(:text)) {
      Fragment.new(template, TextFragment.new(text.join('')))
    }
    rule(substitution: {
        key_expr: simple(:fragment),
        tpl: simple(:tpl)
      }) {
      Substitution.new(fragment, tpl)
    }
    rule(gsub: {
        key_expr: simple(:fragment),
        pattern: sequence(:pattern),
        replacement: simple(:replacement)
      }) {
      Gsub.new(fragment, pattern.join(''), replacement)
    }
    rule(integer: simple(:integer)) {
      integer.to_i
    }
    rule(identifier: simple(:identifier)) {
      LookupFragment.new(identifier.to_s)
    }
    rule(key: simple(:fragment), subscript: simple(:subscript)) {
      LookupFragment.new(fragment, subscript)
    }
    rule(key_expr: simple(:fragment)) {
      LookupFragment.fragment(fragment)
    }
    rule(key: simple(:fragment)) {
      LookupFragment.fragment(fragment)
    }
    rule(subcommand: simple(:command),
         command_line: simple(:command_line)) {
      Subcommand.new(command, command_line)
    }
    rule(function: simple(:function), function_arguments: sequence(:args)) {
      Funcall.new(function.identifier, *args)
    }
    rule(argument: simple(:arg)) { arg }
    rule(argument: sequence(:args)) { Fragment.new(*args).collapse }
    rule(string: sequence(:c)) { c.join('') }
    rule(string: simple(:c)) { c.to_s }
    rule(leftquot: simple(:left),
         rightquot: simple(:right)) {
      left.to_s + right.to_s
    }

    rule(embedded_template: simple(:template)) { template }
    rule(quoted_template: sequence(:fragments)) {
      pieces = fragments.map { |c|
        if c.is_a?(String)
          TextFragment.new(c)
        else
          c
        end
      }
      Fragment.new(*pieces).collapse
    }

    rule(template: simple(:tpl), word: sequence(:fragments)) {
      pieces = fragments.map { |c|
        if c.is_a?(String)
          TextFragment.new(c)
        else
          c
        end
      }
      Fragment.new(tpl, *pieces).collapse
    }

    rule(word: sequence(:fragments)) {
      pieces = fragments.map { |c|
        if c.is_a?(String)
          TextFragment.new(c)
        else
          c
        end
      }
      Fragment.new(*pieces).collapse
    }
  end
end
