require 'parslet'
require 'grammar/atom'
require 'grammar/sql_expr'
require 'query/grammar'

module Grammar
  class QueryTerm < Parslet::Parser
    root(:expr)

    rule(:expr) {
      keyed_options | option | body_term
    }

    rule(:option) {
      (str("-").maybe >> keyed_option).as(:keyed_options) |
      (str("-") >> option_name >>
        (str(":") >> option_argument).repeat.as(:arguments)).as(:option)
    }

    rule(:option_name) {
      Atom.new.identifier.as(:option_name)
    }

    rule(:option_argument) {
      match["^ :"].repeat(1).as(:option_argument)
    }

    rule(:body_expr) {
      QueryBody.new.parenthesized_body | expr
    }

    rule(:body_term) {
      summary_term | extra_term | minmax_term | order_term | game_number | term
    }

    rule(:game_number) {
      Atom.new.integer.as(:game_number) >>
      (space.present? | any.absent? | field_value_boundary.present?)
    }

    def query_fn(prefix, body)
      prefix >> space? >> match[":="] >> space? >> body |
        prefix >> space? >> match["("] >> space? >> body >> space? >>
        match[")"]
    end

    rule(:minmax_term) {
      min_term | max_term
    }

    rule(:min_term) { query_fn(str("min"), field_expr.as(:min)) }
    rule(:max_term) { query_fn(str("max"), field_expr.as(:max)) }

    rule(:order_term) {
      query_fn(str("o") | str("order"), ordered_sort_expression_list).as(:group_order_list)
    }

    rule(:summary_term) {
      query_fn(str("group") | match['sg'],
        ordered_group_expression_list.as(:summary))
    }

    rule(:keyed_options) {
      str("-").maybe >> str("opt") >> match["=:"] >>
      keyed_option_list.as(:keyed_options)
    }

    rule(:keyed_option_list) {
      keyed_option |
      str("(") >> space? >> keyed_option >>
      (space? >> str(",").maybe >> space? >> keyed_option).repeat >>
      space? >> str(")")
    }

    rule(:keyed_option) {
      keyed_option_name >> space? >> match[":"] >> space? >>
      keyed_option_value
    }

    rule(:keyed_option_name) {
      Atom.new.identifier.as(:keyed_option_name)
    }

    rule(:keyed_option_value) {
      Atom.new.quoted_string.as(:keyed_option_value)
    }

    rule(:extra_term) {
      query_fn(str("extra") | str("x"),
        extra_field_expression_list.as(:extra))
    }

    def comma_separated(expr)
      expr >> (space? >> str(",") >> space? >> expr).repeat
    end

    rule(:extra_field_expression_list) {
      comma_separated(extra_field_expr)
    }

    rule(:ordered_group_expression_list) {
      comma_separated(ordered_group_expr)
    }

    rule(:ordered_sort_expression_list) {
      comma_separated(ordered_sort_expr)
    }

    def ordered_expr(expr, capture=:ordering)
      match["+-"].maybe.as(capture) >> expr
    end

    rule(:ordered_group_expr) {
      ordered_expr(field_expr.as(:summary_expr) >> str("%").maybe.as(:percentage))
    }

    rule(:ordered_sort_expr) {
      ordered_expr(
        (match[".%"].as(:sort_group_expr) | field_expr).as(:group_order_term),
        :group_order)
    }

    rule(:extra_field_expr) {
      ordered_expr(field_expr.as(:extra_term)).as(:extra_expr)
    }

    rule(:term_field_expr) {
      (field_expr >> (str('&') >> field_expr).repeat(1)).as(:and_field) |
      (field_expr >> (str('|') >> field_expr).repeat(1)).as(:or_field) |
      field_expr
    }

    rule(:term) {
      term_field_expr.as(:term_expr) >> space? >> op >>
      field_value.as(:value) |
      SqlExpr.new
    }

    rule(:field_expr) {
      function_expr | field | SqlExpr.new
    }

    rule(:field_value_boundary) {
      str("||") | str(")") | str("/") | str("?:")
    }

    rule(:field_value) {
      (SqlExpr.new |
        Atom.new.quoted_string |
        (field_value_boundary.absent? >> Atom.new.safe_value).repeat.as(:field_value))
    }

    rule(:function_expr) {
      (function_name >> space? >> str("(") >> space? >>
        function_arguments.maybe >> space? >> str(")")).as(:function_call)
    }

    rule(:function_arguments) {
      SqlExpr.new.function_arguments.as(:arguments)
    }

    rule(:function_name) {
      identifier.as(:function_name)
    }

    rule(:field) {
      (prefix.maybe >> identifier).as(:identifier).as(:field)
    }

    rule(:prefix) {
      identifier >> str(":")
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
