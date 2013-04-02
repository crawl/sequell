require 'parslet'
require 'grammar/atom'
require 'grammar/sql_expr'
require 'query/grammar'

module Grammar
  class QueryTerm < Parslet::Parser
    root(:expr)

    rule(:expr) {
      body_term | option
    }

    rule(:option) {
      (str("-") >> option_name >>
        (str(":") >> option_argument).repeat.as(:arguments)).as(:option)
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
      summary_term | extra_term | minmax_term | order_term | game_number | term
    }

    rule(:game_number) {
      Atom.new.integer.as(:game_number) >>
      (space.present? || any.absent? | field_value_boundary.present?)
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
        ordered_group_expression_list.as(:summary))
    }

    rule(:extra_term) {
      query_fn(str("extra") | str("x"),
        ordered_field_expression_list.as(:extra))
    }

    def comma_separated(expr)
      expr >> (space? >> str(",") >> space? >> expr).repeat
    end

    rule(:ordered_field_expression_list) {
      comma_separated(ordered_field_expr)
    }

    rule(:ordered_group_expression_list) {
      comma_separated(ordered_group_expr)
    }

    rule(:ordered_sort_expression_list) {
      comma_separated(ordered_sort_expr)
    }

    def ordered_expr(expr)
      match["+-"].maybe.as(:ordering) >> expr
    end

    rule(:ordered_group_expr) {
      ordered_expr(field_expr >> str("%").maybe.as(:percentage))
    }

    rule(:ordered_sort_expr) {
      ordered_expr(str(".").as(:sort_group_expr) | field_expr)
    }

    rule(:ordered_field_expr) {
      ordered_expr(field_expr)
    }

    rule(:term_field_expr) {
      (field_expr >> (str('&') >> field_expr).repeat(1)).as(:and_field) |
      (field_expr >> (str('|') >> field_expr).repeat(1)).as(:or_field) |
      field_expr
    }

    rule(:term) {
      term_field_expr >> space? >> op >>
      (space >> (field_value_boundary | body_expr).absent?).maybe >>
      field_value.as(:value) |
      SqlExpr.new
    }

    rule(:field_expr) {
      function_expr | field
    }

    rule(:field_value_boundary) {
      str("||") | str("))") | str("/") | str("?:")
    }

    rule(:field_value) {
      SqlExpr.new |
      Atom.new.quoted_string |
      (space >> (field_value_boundary | body_expr).absent? |
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
      (prefix.maybe >> identifier.as(:identifier)).as(:field)
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
