require 'parslet'
require 'query/ast/expr'
require 'query/ast/value'
require 'query/ast/option'
require 'query/ast/modifier'
require 'query/ast/keyword'
require 'query/ast/query_ast'
require 'query/nick_expr'
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

      rule(term: {
          option: {
            option_name: simple(:name),
            arguments: sequence(:args)
          }
        }) {
        ::Query::Option.new(name, args)
      }

      rule(field_value: sequence(:value)) {
        ''
      }

      rule(field_value: simple(:value)) {
        value.to_s.strip
      }

      rule(field: { identifier: simple(:field) }) {
        Sql::Field.field(field.to_s)
      }

      rule(and: sequence(:expressions)) {
        Expr.new(:and, *expressions)
      }

      rule(or: sequence(:expressions)) {
        Expr.new(:or, *expressions)
      }

      rule(expr: simple(:expr)) {
        expr
      }

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

      rule(
        term: {
          field: { identifier: simple(:field) },
          op: simple(:op),
          value: simple(:value)
        }) {
        Expr.new(op.to_s, Sql::Field.field(field.to_s), Value.new(value.to_s))
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
        { field: Sql::Field.field(fieldname.to_s) }
      }
    end
  end
end
