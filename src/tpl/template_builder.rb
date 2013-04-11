require 'parslet'

require 'tpl/fragment'
require 'tpl/text_fragment'
require 'tpl/lookup_fragment'
require 'tpl/substitution'
require 'tpl/gsub'

module Tpl
  class TemplateBuilder < Parslet::Transform
    rule(tpl: simple(:tpl)) {
      tpl.collapse
    }
    rule(tpl: sequence(:fragments)) {
      Fragment.new(*fragments).collapse
    }
    rule(char: simple(:c)) { c.to_s }
    rule(text: sequence(:c)) { TextFragment.new(c.join('')) }
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
  end
end
