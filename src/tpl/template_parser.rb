require 'parslet'
require 'grammar/atom'
require 'grammar/config'
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
        number | word_paren_form | balanced_brackets(word.as(:body)) |
        match[' \]'].absent? >> tchar).repeat
    }

    rule(:number) {
      ::Grammar::Atom.new.number.as(:number)
    }

    rule(:word_paren_form) {
      str("(") >> space? >> (template_subcommand | template_paren_form) >>
      space? >> str(")")
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
      str("$") >> (identifier.as(:key) >> subscript.maybe).as(:key_expr) |
      str("${") >> space? >> template_with_options >> space? >> str("}") |
      str("$(") >> space? >> (template_subcommand | template_paren_form) >>
        space? >> str(")") |
      (str("${") >> match['^}'].repeat >> str("}")).as(:raw) |
      (str("$(") >> match['^)'].repeat >> str(")")).as(:raw)
    }

    rule(:template_subcommand) {
      sigils = Regexp.quote(::Henzell::Config.default[:sigils])
      ((reserved_name >> space | str("$(")).absent? >> match[sigils] >>
        subcommand_name_part).as(:subcommand) >>
        subcommand_line.as(:command_line)
    }

    rule(:reserved_name) {
      ::Grammar::Config['reserved-names'].map { |name| str(name) }.reduce(&:|).as(:identifier)
    }

    rule(:subcommand_line) {
      subtpl
    }

    rule(:balanced_group) {
      balanced_curly | balanced_paren | balanced_brackets(subtpl.as(:body))
    }

    rule(:balanced_curly) {
      (str("{").as(:leftquot) >> subtpl.as(:body) >> str("}").as(:rightquot)).as(:balanced)
    }

    rule(:balanced_paren) {
      (str("(").as(:leftquot) >> subtpl.as(:body) >> str(")").as(:rightquot)).as(:balanced)
    }

    def balanced_brackets(body)
      (str("[").as(:leftquot) >> body >> str("]").as(:rightquot)).as(:balanced)
    end

    rule(:template_paren_form) {
      template_special_form | function_def | template_funcall
    }

    rule(:template_special_form) {
      let_form
    }

    rule(:let_form) {
      str("let").as(:let_form) >> space? >>
      binding_form >>
      space? >> subcommand_line.as(:body)
    }

    rule(:binding_form) {
      str("(") >> bindings.as(:bindings) >> space? >> str(")")
    }

    rule (:bindings) {
      binding.repeat
    }

    rule (:binding) {
      space? >> identifier.as(:binding_name) >> space >> wordtpl.as(:value)
    }

    rule(:template_funcall) {
      str("let").absent? >>
      (str("$").maybe >> str("(") >> space? >> function_def >>
          space? >> str(")") | identifier | reserved_name).as(:function) >>
      funargs.as(:function_arguments)
    }

    rule(:funargs) {
      (space >>
        ((number >> ((space | str(")")).present? | any.absent?)) |
          wordtpl)
      ).as(:argument).repeat
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

    rule(:function_def) {
      (str("fn") >>
        (((space >> identifier).maybe.as(:function_name) >> space >>
          function_parameters.as(:parameters)) |
         space >> function_parameters.maybe.as(:parameters)) >>
        space? >>
        subcommand_line.as(:body)).as(:function_def)
    }

    rule(:function_parameters) {
      str("(") >> function_parameter_list >> space? >> str(")")
    }

    rule(:function_parameter_list) {
      (space? >> str(".").absent? >> identifier.as(:parameter)).repeat.as(:parameters) >>
      (space? >> str(".") >> space >> identifier).maybe.as(:rest_parameter)
    }

    rule(:template_key) {
      ((identifier | template | reserved_name).as(:key) >>
        subscript.maybe).as(:key_expr)
    }

    rule(:subscript) {
      str("[") >> space? >> (integer | wordtpl).as(:subscript) >> space? >>
      str("]")
    }

    rule(:identifier) {
      (match["a-zA-Z_0-9*"] >> match["a-zA-Z_0-9*+-"].repeat >> str("?").maybe |
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
