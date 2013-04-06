require 'parslet'
require 'grammar/nick'
require 'grammar/keyword'
require 'grammar/query_term'

module Grammar
  class QueryBody < Parslet::Parser
    root(:body_root)

    rule(:nick_expr) { Nick.new >> space.present? | Nick.new >> any.absent? }

    rule(:nick_body) {
      (nick_expr.maybe >>
        space.repeat >>
        body_root.as(:body).maybe).as(:nick_and_body)
    }

    rule(:body_root) {
      body_alternation | body_expressions
    }

    rule(:body_alternation) {
      (body_expressions.as(:expr) >> (space? >> str("||") >> space? >>
                     body_expressions.as(:expr)).repeat(1)).as(:or)
    }

    rule(:body_expressions) {
      (space? >> body_expr).repeat(1).as(:and)
    }

    rule(:body_expr) {
      parenthesized_body | body_term
    }

    rule(:parenthesized_body) {
      (str("!") >> space? >> parenthesized_body).as(:negated) |
        parenthesized_body_unprefixed
    }

    rule(:parenthesized_body_unprefixed) {
      str("((") >> space? >> body_root.as(:parentheses) >>
       space? >> str("))")
    }

    rule(:body_term) {
      keyword_expr.as(:keyword_expr) | query_expression
    }

    rule(:query_expression) {
      query_term.as(:expr)
    }

    rule(:query_term) {
      QueryTerm.new.as(:term)
    }

    rule(:keyword_expr) {
      game_number | (query_expression.absent? >> Keyword.new)
    }

    rule(:game_number) {
      QueryTerm.new.game_number
    }

    rule(:space) {
      match('\s')
    }

    rule(:space?) {
      space.maybe
    }
  end
end
