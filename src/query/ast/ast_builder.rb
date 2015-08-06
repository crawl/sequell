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
require 'query/ast/keyed_option_list'
require 'query/ast/keyed_option'
require 'query/ast/funcall'
require 'query/ast/exists_expr'
require 'query/ast/window_funcall'
require 'query/ast/window_partition'
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
        debug{"Creating QueryAST: head: #{head}, tail: #{tail}, filter: #{filter}"}
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
        value.is_a?(Term) ? value : value.to_s.strip
      }

      rule(field: { identifier: simple(:field) }) {
        Field.new(field)
      }

      rule(window_function_expr: simple(:window_funcexp),
           partition: simple(:partition)) {
        WindowFuncall.new(window_funcexp, partition)
      }

      rule(window_funcall: simple(:window_funcall)) {
        window_funcall
      }

      rule(partition_exprs: simple(:expr),
           partition_order: simple(:partition_group_order)) {
        WindowPartition.new([expr], partition_group_order)
      }

      rule(partition_exprs: sequence(:exprs),
           partition_order: simple(:partition_group_order)) {
        WindowPartition.new(exprs, partition_group_order)
      }

      rule(function_call: simple(:funcall)) { funcall }
      rule(function_argument: simple(:argument)) {
        if argument.is_a?(String) || argument.is_a?(Numeric)
          Value.new(argument)
        else
          argument
        end
      }
      rule(star: simple(:star)) {
        star.to_s
      }
      rule(function_name: simple(:name)) {
        Funcall.new(name.to_s)
      }
      rule(function_name: simple(:name), star: simple(:star)) {
        Funcall.new(name.to_s, star)
      }
      rule(function_name: simple(:name),
           arguments: simple(:argument)) {
        Funcall.new(name.to_s, *([argument].compact))
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
      rule(sql_expr: simple(:expr)) { expr.with_flags(sql_expr: true) }

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

      rule(number: simple(:num)) { num }

      rule(integer: simple(:num)) { Value.new(num.to_i) }
      rule(float: simple(:num)) { Value.new(num.to_f) }

      rule(plus: simple(:number)) { number }
      rule(arithmetic_negated: simple(:number)) { Value.new(-number.value) }

      rule(op: simple(:op), right: simple(:value)) {
        OpenStruct.new(op: op.to_s, value: value)
      }

      rule(left: simple(:left), op: simple(:op), right: simple(:right)) {
        Expr.new(op.to_s, left, right)
      }

      rule(left: simple(:left), right_partial: sequence(:op_right)) {
        op_right.reduce(left) { |term, right|
          Expr.new(right.op, term, right.value)
        }
      }

      rule(
        term: {
          term_expr: simple(:expr),
          op: simple(:op),
          value: simple(:value)
        }) {
        Expr.new(op.to_s, expr,
          value.is_a?(Term) ? value : Value.new(value.to_s))
      }

      rule(
        term: {
          term_expr: {
            and_field: sequence(:fields)
          },
          op: simple(:op),
          value: simple(:value)
        }) {
        Expr.new(:and,
          *fields.map { |field|
            Expr.new(op.to_s, field,
              value.is_a?(Term) ? value : Value.new(value.to_s))
          })
      }

      rule(
        term: {
          term_expr: {
            or_field: sequence(:fields)
          },
          op: simple(:op),
          value: simple(:value)
        }) {
        Expr.new(:or,
          *fields.map { |field|
            Expr.new(op.to_s, field,
                     value.is_a?(Term) ? value : Value.new(value.to_s))
          })
      }

      rule(field: { identifier: simple(:fieldname) }) {
        { field: Field.new(fieldname) }
      }

      rule(ordering: simple(:ordering),
           summary_expr: simple(:expr),
           percentage: simple(:percentage)) {
        Summary.new(expr, ordering.to_s, percentage.to_s)
      }

      rule(extra_expr: {
          ordering: simple(:ordering),
          extra_term: simple(:term),
          extra_alias: simple(:ealias)
        }) {
        Extra.new(term, ordering.to_s, ealias.to_s)
      }

      rule(suffix_alias: simple(:alias_name)) {
        alias_name.to_s
      }

      rule(subquery: {
             context: simple(:context),
             body: simple(:expr),
             alias: simple(:query_alias)
           }) {
        QueryAST.new(context.to_s, expr, nil, nil, :subquery).as_subquery(query_alias.to_s)
      }

      rule(table_subquery: simple(:subquery)) {
        subquery.table_subquery = true
        subquery
      }

      rule(exists_subquery: simple(:subquery)) {
        ExistsExpr.new(subquery)
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

      rule(char: simple(:c)) { c.to_s }
      rule(string: sequence(:chars)) { chars.join('') }

      rule(keyed_option_name: simple(:name),
           keyed_option_value: simple(:value)) {
        KeyedOption.new(name.to_s, value.to_s)
      }

      rule(keyed_options: simple(:keyed_option)) {
        KeyedOptionList.new(keyed_option)
      }
      rule(keyed_options: sequence(:keyed_options)) {
        KeyedOptionList.new(*keyed_options)
      }
    end
  end
end
