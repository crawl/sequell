require 'parslet'

module Grammar
  class QueryResultFilter < Parslet::Parser
    root(:result_filter)

    rule(:result_filter) {
      result_alternation | result_expressions
    }

    rule(:result_alternation) {
      (result_expressions >> space? >>
        str("||") >> space? >> result_expressions).as(:filter_or)
    }

    rule(:result_expressions) {
      (space? >> result_expression).repeat(1).as(:filter_and)
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
      (numerator | denominator | ratio) >> match[":."]
    }

    rule(:ratio) {
      str("%").as(:ratio)
    }

    rule(:numerator) {
      (str("num") | str("n")).as(:numerator)
    }

    rule(:denominator) {
      (str("den") | str("d")).as(:denominator)
    }

    rule(:field_expression) {
      (function_expr | str("N") | str("n") | str("%")).as(:filter_expr)
    }

    rule(:function_expr) {
      QueryTerm.new.function_expr
    }

    rule(:space) { match('\s') }
    rule(:space?) { space.maybe }
  end
end
