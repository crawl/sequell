require 'parslet'
require 'query/ast/expr'
require 'query/ast/value'
require 'query/ast/option_builder'
require 'query/ast/modifier'
require 'query/ast/keyword'
require 'query/ast/query_ast'
require 'query/ast/summary'
require 'query/ast/summary_list'
require 'query/ast/extra'
require 'query/ast/extra_list'
require 'query/ast/field'
require 'query/ast/filter_expr'
require 'query/ast/filter_term'
require 'query/ast/filter_value'
require 'query/ast/group_order_term'
require 'query/ast/group_order_list'
require 'query/ast/funcall'
require 'query/nick_expr'
require 'query/sort'
require 'sql/field'

module Query
  module AST
    class ASTBuilder < Parslet::Transform
      rule(query: simple(:query)) {
        query
      }

      rule(context: simple(:context),
        head: simple(:head),
        tail: simple(:tail),
        filter: simple(:filter)) {
        debug("Creating QueryAST: head: #{head}, tail: #{tail}, filter: #{filter}")
        QueryAST.new(context, head, tail, filter)
      }

      rule(nick_and_body: simple(:empty)) {
        Expr.and
      }

      rule(nick_and_body: {
          nick_expr: simple(:nick),
          body: simple(:body)
        }) {
        Expr.and(NickExpr.nick(nick), body)
      }

      rule(nick_and_body: {
          nick_expr: simple(:nick)
        }) {
        Expr.and(NickExpr.nick(nick))
      }

      rule(nick_and_body: {
          body: simple(:body)
        }) {
        Expr.and(body)
      }

      rule(ratio: simple(:ratio)) {
        ratio
      }

      rule(nick: simple(:nick)) {
        Value.new(nick)
      }

      rule(negated_nick: simple(:nick)) {
        NickExpr.negated(nick)
      }

      rule(game_number: simple(:number)) {
        Modifier.new(:game_number, number.to_i)
      }

      rule(option_argument: simple(:arg)) { arg.to_s }
      rule(term: {
          option: {
            option_name: simple(:name),
            arguments: sequence(:args)
          }
        }) {
        ::Query::AST::OptionBuilder.build(name.to_s, args)
      }

      rule(term: {
          option: {
            option_name: simple(:name)
          }
        }) {
        ::Query::AST::OptionBuilder.build(name.to_s, [])
      }

      rule(field_value: sequence(:value)) {
        ''
      }

      rule(field_value: simple(:value)) {
        value.to_s.strip
      }

      rule(field: { identifier: simple(:field) }) {
        Field.new(field)
      }

      rule(function_call: simple(:funcall)) { funcall }

      rule(function_name: simple(:name),
           arguments: simple(:argument)) {
        Funcall.new(name.to_s, argument)
      }
      rule(function_name: simple(:name),
           arguments: sequence(:arguments)) {
        Funcall.new(name.to_s, *arguments)
      }

      rule(and: sequence(:expressions)) {
        Expr.new(:and, *expressions)
      }

      rule(or: sequence(:expressions)) {
        Expr.new(:or, *expressions)
      }

      rule(expr: simple(:expr)) { expr }
      rule(term: simple(:term)) { term }

      rule(keyword_expr: simple(:keyword)) {
        keyword
      }

      rule(negated: simple(:any)) {
        Expr.new(:not, any)
      }

      rule(parentheses: simple(:any)) {
        any
      }

      rule(keyword: simple(:keyword)) {
        AST::Keyword.new(keyword.to_s)
      }

      rule(term: {
          function_call: simple(:funcall),
          op: simple(:op),
          value: simple(:value)
        }) {
        Expr.new(op.to_s, funcall, Value.new(value.to_s))
      }

      rule(
        term: {
          field: { identifier: simple(:field) },
          op: simple(:op),
          value: simple(:value)
        }) {
        Expr.new(op.to_s, Field.new(field), Value.new(value.to_s))
      }

      rule(
        term: {
          and_field: sequence(:fields),
          op: simple(:op),
          value: simple(:value)
        }) {
        Expr.new(:and,
          *fields.map { |field|
            Expr.new(op.to_s, field, Value.new(value.to_s))
          })
      }

      rule(
        term: {
          or_field: sequence(:fields),
          op: simple(:op),
          value: simple(:value)
        }) {
        Expr.new(:or,
          *fields.map { |field|
            Expr.new(op.to_s, field, Value.new(value.to_s))
          })
      }

      rule(field: { identifier: simple(:fieldname) }) {
        { field: Field.new(fieldname) }
      }

      rule(ordering: simple(:ordering),
           field: { identifier: simple(:field) },
           percentage: simple(:percentage)) {
        Summary.new(Field.new(field), ordering.to_s,
                    percentage.to_s)
      }


      rule(ordering: simple(:ordering),
           function_call: simple(:funcall),
           percentage: simple(:percentage)) {
        Summary.new(funcall, ordering.to_s, percentage.to_s)
      }

      rule(extra_expr: {
          ordering: simple(:ordering),
          extra_term: simple(:term)
        }) {
        Extra.new(term, ordering.to_s)
      }

      rule(extra: sequence(:extra)) { ExtraList.new(*extra) }
      rule(extra: simple(:extra)) { ExtraList.new(extra) }

      rule(max: simple(:expr)) { Query::Sort.new(expr, 'DESC') }
      rule(min: simple(:expr)) { Query::Sort.new(expr, 'ASC') }

      rule(summary: sequence(:summary)) {
        SummaryList.new(*summary)
      }
      rule(summary: simple(:summary)) {
        SummaryList.new(summary)
      }

      rule(term: simple(:term)) {
        term
      }

      rule(filter_expr: simple(:filter_expr),
           op: simple(:op),
           value: simple(:value)) {
        FilterExpr.predicate(
          op,
          FilterTerm.term(filter_expr.to_s),
          FilterValue.new(value.to_s))
      }

      rule(filter_expr: simple(:filter_expr),
           denominator: simple(:denominator),
           op: simple(:op),
           value: simple(:value)) {
        FilterExpr.predicate(
          op,
          FilterTerm.term(filter_expr.to_s, denominator: true),
          FilterValue.new(value.to_s))
      }

      rule(filter_expr: simple(:filter_expr),
           numerator: simple(:numerator),
           op: simple(:op),
           value: simple(:value)) {
        FilterExpr.predicate(
          op,
          FilterTerm.term(filter_expr.to_s, numerator: true),
          FilterValue.new(value.to_s))
      }

      rule(filter_expr: simple(:filter_expr),
           ratio: simple(:ratio),
           op: simple(:op),
           value: simple(:value)) {
        FilterExpr.predicate(
          op,
          FilterTerm.term(filter_expr.to_s, ratio: true),
          FilterValue.new(value.to_s))
      }

      rule(sort_group_expr: simple(:expr)) { FilterTerm.term(expr) }

      rule(group_order: simple(:group_order),
           group_order_term: simple(:term)) {
        GroupOrderTerm.new(FilterTerm.term(term), group_order)
      }

      rule(group_order_list: sequence(:group_order)) {
        GroupOrderList.new(*group_order)
      }
      rule(group_order_list: simple(:group_order)) {
        GroupOrderList.new(group_order)
      }

      rule(filter_and: sequence(:filter_expr)) {
        FilterExpr.new(:and, *filter_expr)
      }
      rule(filter_or: sequence(:filter_expr)) {
        FilterExpr.new(:or, *filter_expr)
      }
      rule(result_filter: simple(:filter_expr)) {
        filter_expr
      }
    end
  end
end
