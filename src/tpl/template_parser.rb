require 'parslet'
require 'grammar/atom'
require 'henzell/config'

module Tpl
  class TemplateParser < Parslet::Parser
    root(:tpl)

    rule(:tpl) {
      (text.as(:text) >> (template.as(:template) >> text.as(:text)).repeat).as(:tpl)
    }

    rule(:subtpl) {
      (safetext.as(:text) >> (template.as(:template) >> safetext.as(:text)).repeat).as(:tpl)
    }

    rule(:wordtpl) {
      word.as(:word) >> (template.as(:template) >> word.as(:word)).repeat
    }

    rule(:word) {
      (single_quoted_string | double_quoted_template.as(:quoted_template) |
        str(" ").absent? >> tchar).repeat
    }

    rule(:double_quoted_template) {
      str('"') >>
      (str("\\") >> str("\\").as(:char) |
        str("\\") >> str("\"").as(:char) |
        template.as(:embedded_template) |
        match['^"'].as(:char)).repeat >>
      str('"')
    }

    rule(:single_quoted_string) {
      ::Grammar::Atom.new.single_quoted_string
    }

    rule(:text) {
      (single_quoted_text | tchar | match["})"].as(:char)).repeat
    }

    rule(:safetext) {
      (balanced_group | single_quoted_text | tchar.as(:char)).repeat
    }

    rule(:single_quoted_text) {
      ::Grammar::Atom.new.wrapped_single_quoted_string
    }

    rule(:tchar) {
      str("\\") >> str("}").as(:char) |
      str("\\") >> str(")").as(:char) |
      str("\\") >> str("\\").as(:char) |
      str("\\") >> str("$").as(:char) |
      str("$").as(:char) >> (match['^({A-Za-z0-9*_'].present? | any.absent?) |
      match['^$})'].as(:char)
    }

    rule(:template) {
      str("$") >> identifier |
      str("${") >> space? >> template_with_options >> space? >> str("}") |
      str("$(") >> space? >> (template_subcommand | template_funcall) >>
        space? >> str(")") |
      (str("${") >> match['^}'].repeat >> str("}")).as(:raw) |
      (str("$(") >> match['^)'].repeat >> str(")")).as(:raw)
    }

    rule(:template_subcommand) {
      sigils = Regexp.quote(::Henzell::Config.default[:sigils])
      (match[sigils] >> subcommand_name_part).as(:subcommand) >>
        subcommand_line.as(:command_line)
    }

    rule(:subcommand_line) {
      subtpl
    }

    rule(:balanced_group) {
      balanced_curly | balanced_paren
    }

    rule(:balanced_curly) {
      (str("{").as(:leftquot) >> subtpl.as(:body) >> str("}").as(:rightquot)).as(:balanced)
    }

    rule(:balanced_paren) {
      (str("(").as(:leftquot) >> subtpl.as(:body) >> str(")").as(:rightquot)).as(:balanced)
    }

    rule(:template_funcall) {
      identifier.as(:function) >> funargs.as(:function_arguments)
    }

    rule(:funargs) {
      (space >> wordtpl.as(:argument)).repeat
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
      ((identifier | template).as(:key) >>
        subscript.maybe).as(:key_expr)
    }

    rule(:subscript) {
      str("[") >> space? >> integer.as(:subscript) >> space? >> str("]")
    }

    rule(:identifier) {
      (match["a-zA-Z_0-9*"] >> match["a-zA-Z_0-9*+-"].repeat |
       str(".") | str("*") | str("%")).as(:identifier)
    }

    rule(:subcommand_name_part) {
      match['^ )'].repeat
    }

    rule(:integer) {
      (match["+-"].maybe >> match["0-9"].repeat(1)).as(:integer)
    }

    rule(:space) { match('\s').repeat(1) }
    rule(:space?) { space.maybe }
  end
end
