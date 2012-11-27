require 'parslet'

module Grammar
  class QueryResultFilter < Parslet::Parser
    root(:result_filter)

    rule(:result_filter) {
      result_alternation | result_expressions
    }

    rule(:result_alternation) {
      (result_expressions >> space? >>
        str("|") >> space? >> result_expressions).as(:or)
    }

    rule(:result_expressions) {
      (result_expression >> (space >> result_expression).repeat).as(:and)
    }

    rule(:result_expression) {
      parenthesized_expression | simple_expression
    }

    rule(:parenthesized_expression) {
      str("!") >> space? >> parenthesized_expression.as(:negated) |
        parenthesized_expression_unprefixed
    }

    rule(:parenthesized_expression_unprefixed) {
      str("(") >> space? >> result_filter.as(:parentheses) >> space? >>
        str(")")
    }

    rule(:simple_expression) {
      filter_expression >> space? >> filter_op >> space? >> filter_value
    }

    rule(:filter_op) {
      (str("!=") | str("=") | str("<=") | str(">=") |
       str("<") | str(">")).as(:op)
    }

    rule(:filter_value) {
      Atom.new.number.as(:value)
    }

    rule(:filter_expression) {
      qualifier.maybe >> field_expression
    }

    rule(:qualifier) {
      (numerator | denominator) >> match[":."]
    }

    rule(:numerator) {
      (str("num") | str("n")).as(:numerator)
    }

    rule(:denominator) {
      (str("den") | str("d")).as(:denominator)
    }

    rule(:field_expression) {
      (function_expr | str("N") | str("n") | str("%")).as(:expr)
    }

    rule(:function_expr) {
      QueryTerm.new.function_expr
    }

    rule(:space) { match('\s') }
    rule(:space?) { space.maybe }
  end
end
