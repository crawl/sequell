require 'parslet'
require 'grammar/nick'
require 'grammar/keyword'
require 'grammar/query_term'

module Grammar
  class QueryBody < Parslet::Parser
    root(:body_root)

    rule(:body_root) {
      body_alternation | body_expressions
    }

    rule(:body_alternation) {
      (body_expressions >> (space? >> str("||") >> space? >>
                     body_expressions).repeat(1)).as(:or)
    }

    rule(:body_expressions) {
      (body_expr >> (space >> body_expr).repeat).as(:and)
    }

    rule(:body_expr) {
      parenthesized_body | body
    }

    rule(:parenthesized_body) {
      (str("!") >> parenthesized_body).as(:negated) |
        parenthesized_body_unprefixed
    }

    rule(:parenthesized_body_unprefixed) {
      str("((") >> space? >> body_root.as(:parentheses) >>
       space? >> str("))")
    }

    rule(:body) {
      keywords >> space >> query_expressions |
        keywords |
        query_expressions
    }

    rule(:keywords) {
      keyword_expr >> (space >> keyword_expr).repeat
    }

    rule(:query_expressions) {
      query_expression >> (space >> query_expression).repeat
    }

    rule(:query_expression) {
      game_number | query_term
    }

    rule(:query_term) {
      QueryTerm.new.as(:term)
    }

    rule(:keyword_expr) {
      game_number | (query_expression.absent? >> Keyword.new)
    }

    rule(:game_number) {
      Atom.new.integer.as(:game_number)
    }

    rule(:space) {
      match('\s')
    }

    rule(:space?) {
      space.maybe
    }
  end
end
