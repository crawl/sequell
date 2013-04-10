require 'parslet'

module Tpl
  class TemplateParser < Parslet::Parser
    root(:tpl)

    rule(:tpl) {
      (text.as(:text) >> (template.as(:template) >> text.as(:text)).repeat).as(:tpl)
    }

    rule(:subtpl) {
      (safetext.as(:text) >> (template.as(:template) >> safetext.as(:text)).repeat).as(:tpl)
    }

    rule(:text) {
      (tchar | str("}").as(:char)).repeat
    }

    rule(:safetext) {
      tchar.as(:char).repeat
    }

    rule(:tchar) {
      str("\\") >> str("}").as(:char) |
      str("\\") >> str("\\").as(:char) |
      str("\\") >> str("$").as(:char) |
      str("$").as(:char) >> (match['^{A-Za-z0-9*_'].present? | any.absent?) |
      match['^\\\$}'].as(:char)
    }

    rule(:template) {
      str("$") >> identifier |
      str("${") >> space? >> template_with_options >> space? >>
      str("}")
    }

    rule(:template_with_options) {
      (template_key >> str(":-") >> subtpl.as(:tpl)).as(:substitution) |
      (template_key >> str("//") >>
        (match["/}"].absent? >> tchar).repeat.as(:pattern) >> str("/") >>
        subtpl.as(:replacement)).as(:gsub) |
      # (template_key >> str("##") >> intext.as(:match)).as(:hash_greedy) |
      # (template_key >> str("#") >> intext.as(:match)).as(:hash) |
      # (template_key >> str("%%") >> intext.as(:match)).as(:perc_greedy) |
      # (template_key >> str("%") >> intext.as(:match)).as(:perc) |
      template_key
    }

    rule(:intext) {
      text
    }

    rule(:template_key) {
      (identifier | template).as(:key)
    }

    rule(:identifier) {
      (match["a-zA-Z_0-9*"] >> match["a-zA-Z_0-9*+"].repeat |
       str(".") | str("*") | str("%")).as(:identifier)
    }

    rule(:space) { match('\s').repeat(1) }
    rule(:space?) { space.maybe }
  end
end
