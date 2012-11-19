require 'parslet'
require 'grammar/atom'

module Grammar
  class QueryTerm < Parslet::Parser
    root(:expr)

    rule(:expr) {
      body_term | option
    }

    rule(:option) {
      (str("-") >> option_name >>
        (str(":") >> option_argument).repeat).as(:option)
    }

    rule(:option_name) {
      Atom.new.identifier.as(:option_name)
    }

    rule(:option_argument) {
      match["^ :"].repeat(1).as(:argument)
    }

    rule(:body_expr) {
      QueryBody.new.parenthesized_body | body_term
    }

    rule(:body_term) {
      summary_term | extra_term | term
    }

    rule(:summary_term) {
      str("s") >> space? >> match[":="] >> space? >>
      field_expression_list.as(:summary) |
      str("s") >> space? >> match["("] >> space? >>
      field_expression_list.as(:summary) >> space? >> match[")"]
    }

    rule(:extra_term) {
      str("x") >> space? >> match[":="] >> space? >>
      field_expression_list.as(:extra) |
      str("x") >> space? >> match["("] >> space? >>
      field_expression_list.as(:extra) >> space? >> match[")"]
    }

    rule(:field_expression_list) {
      field_expr >> (space? >> str(",") >> space? >> field_expr).repeat
    }

    rule(:term) {
      field_expr >> space? >> op >>
      (space >> field_value_boundary.absent?).maybe >>
      field_value.as(:value)
    }

    rule(:field_expr) {
      function_expr | field
    }

    rule(:field_value_boundary) {
      str("||") | str("))") | str("/") | str("?:") | body_expr
    }

    rule(:field_value) {
      Atom.new.quoted_string |
      Atom.new.number |
      (match('\s') >> field_value_boundary.absent? |
       field_value_boundary.absent? >> Atom.new.safe_value).repeat
    }

    rule(:function_expr) {
      (function_name >> space? >> str("(") >> space? >>
        function_arguments.maybe >> space? >> str(")")).as(:function_call)
    }

    rule(:function_arguments) {
      (field_expr >> (space? >> str(",") >> space? >> field_expr).repeat).as(:arguments)
    }

    rule(:function_name) {
      identifier.as(:function_name)
    }

    rule(:field) {
      (prefix.maybe >> identifier).as(:field)
    }

    rule(:prefix) {
      identifier.as(:prefix) >> str(":")
    }

    rule(:identifier) {
      Atom.new.identifier
    }

    rule(:integer) {
      Atom.new.integer
    }

    rule(:op) {
      (str("!==") | str("==") | str("!~") | str("=~") |
       str("<=") | str(">=") | str("<") | str(">") |
       str("!~~") | str("~~") | str("!=") | str("=")).as(:op)
    }

    rule(:space?) { space.maybe }
    rule(:space) { match('\s').repeat(1) }
  end
end
