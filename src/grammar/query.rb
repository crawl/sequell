require 'parslet'
require 'grammar/nick'
require 'grammar/query_body'

module Grammar
  class Query < Parslet::Parser
    root(:query)

    rule(:query) {
      query_context >>
        (space >> nick_expr).maybe >>
        (space >> query_body).maybe >>
        (space? >> query_tail).maybe >>
        (space? >> query_result_filter).maybe
    }

    rule(:query_context) {
      str("!lg").as(:context_lg) |
      str("!lm").as(:context_lm)
    }

    rule(:query_body) { QueryBody.new }
    rule(:query_tail) { any.absent? }
    rule(:query_result_filter) { any.absent? }

    rule(:nick_expr) { Nick.new }

    rule(:negated) { str("!").as(:negated) }

    rule(:space) { match('\s').repeat(1) }
    rule(:space?) { space.maybe }
  end
end
