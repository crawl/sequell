require 'parslet'
require 'grammar/nick'
require 'grammar/keyword'
require 'grammar/query_term'

module Grammar
  class QueryBody < Parslet::Parser
    root(:body)

    rule(:body) {
      keywords.maybe >> (space? >> query_expressions).maybe
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
