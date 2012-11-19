require 'parslet'
require 'grammar/atom'
require 'query/grammar'

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
      summary_term | extra_term | minmax_term | order_term | term
    }

    def query_fn(prefix, body)
      prefix >> space? >> match[":="] >> space? >> body |
        prefix >> space? >> match["("] >> space? >> body >> space? >>
        match[")"]
    end

    rule(:minmax_term) {
      min_term | max_term
    }

    rule(:min_term) { query_fn(str("min"), field_expr.as(:max)) }
    rule(:max_term) { query_fn(str("max"), field_expr.as(:min)) }

    rule(:order_term) {
      query_fn(str("o") | str("order"), ordered_sort_expression_list)
    }

    rule(:summary_term) {
      query_fn(str("group") | match['sg'],
        ordered_field_expression_list.as(:summary))
    }

    rule(:extra_term) {
      query_fn(str("extra") | str("x"),
        ordered_field_expression_list.as(:extra))
    }

    rule(:ordered_field_expression_list) {
      ordered_field_expr >>
      (space? >> str(",") >> space? >> ordered_field_expr).repeat
    }

    rule(:ordered_sort_expression_list) {
      ordered_sort_expr >>
      (space? >> str(",") >> space? >> ordered_sort_expr).repeat
    }

    def ordered_expr(expr)
      match["+-"].maybe.as(:ordering) >> expr
    end

    rule(:ordered_sort_expr) {
      ordered_expr(str(".").as(:sort_group_expr) | field_expr)
    }

    rule(:ordered_field_expr) {
      ordered_expr(field_expr)
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
      ::Query::Grammar.operators_by_length.map { |x| str(x) }.reduce(&:|).
        as(:op)
    }

    rule(:space?) { space.maybe }
    rule(:space) { match('\s').repeat(1) }
  end
end
