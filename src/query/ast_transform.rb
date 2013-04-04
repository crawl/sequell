require 'parslet'
require 'query/expr'
require 'query/value'
require 'query/option'
require 'sql/field'

module Query
  class ASTTransform < Parslet::Transform
    rule(context: simple(:context),
         query: simple(:query)) {
      query.context = context.to_s
      query
    }

    rule(nick_and_body: {
        nick_expr: simple(:nick),
        body: simple(:body)
      }) {
      Expr.and(nick, body)
    }

    rule(nick: simple(:nick)) {
      nick
    }

    rule(nick_expr: {
        negated_nick: simple(:nick)
      }) {
      NickExpr.negated(nick)
    }

    rule(nick_expr: simple(:nick)) {
      NickExpr.nick(nick)
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

    rule(
      term: {
        field: { identifier: simple(:field) },
        op: simple(:op),
        value: simple(:value)
      }) {
      Expr.new(op.to_s, Sql::Field.field(field.to_s), Value.new(value.to_s))
    }

    rule(field: { identifier: simple(:field) }) {
      Sql::Field.field(field.to_s)
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

    rule(:body_and => sequence(:expressions)) {
      Expr.new(:and, *expressions)
    }

    rule(:body_or => sequence(:expressions)) {
      Expr.new(:or, *expressions)
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
