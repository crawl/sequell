require 'parslet'
require 'grammar/atom'

module Grammar
  class QueryTerm < Parslet::Parser
    root(:expr)

    rule(:expr) {
      alternation | term
    }

    rule(:alternation) {
      (term >> (space? >> str("|") >> space? >> term).repeat(1)).as(:or)
    }

    rule(:term) {
      (str("!") >> space? >> term_unprefixed).as(:negated) |
        term_unprefixed
    }

    rule(:term_unprefixed) {
      parenthesized_term | simple_term
    }

    rule(:parenthesized_term) {
      str("(") >> space? >> expr.as(:parentheses) >> space? >> str(")")
    }

    rule(:simple_term) {
      field_expr >> space? >> op >> space? >> field_value
    }

    rule(:field_expr) {
      function_expr | field
    }

    rule(:field_value) {
      ((str(" ") >> (integer | expr)).absent? >> str(" ") |
        Atom.new.simple_value).repeat.as(:field_value)
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
