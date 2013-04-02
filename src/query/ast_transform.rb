require 'parslet'
require 'query/expr'

module Query
  class ASTTransform < Parslet::Transform
    rule(context: simple(:context),
         query: simple(:query)) {
      query.context_name = context
    }

    rule(nick_and_body: {
        nick: simple(:nick),
        body: simple(:body)
      }) {
      Expr.and([nick, body])
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
  end
end
