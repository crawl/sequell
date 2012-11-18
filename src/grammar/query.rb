require 'parslet'
require 'grammar/nick'
require 'grammar/query_body'
require 'grammar/query_result_filter'

module Grammar
  class Query < Parslet::Parser
    root(:query)

    rule(:query) {
      space? >>
        query_context >>
        (space >> nick_expr).maybe >>
        (space >> query_body.as(:body)).maybe >>
        (space? >> query_tail).maybe >>
        (space? >> query_result_filter).maybe >>
        space?
    }

    rule(:query_context) {
      str("!lg").as(:context_lg) |
      str("!lm").as(:context_lm)
    }

    rule(:query_body) { QueryBody.new }

    rule(:query_tail) {
      str("/") >> space? >> query_body.as(:ratio)
    }

    rule(:query_result_filter) {
      str("?:") >> space? >> QueryResultFilter.new.as(:result_filter)
    }

    rule(:nick_expr) { Nick.new }

    rule(:negated) { str("!").as(:negated) }

    rule(:space) { match('\s').repeat(1) }
    rule(:space?) { space.maybe }
  end
end
