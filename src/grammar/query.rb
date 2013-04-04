require 'parslet'
require 'grammar/nick'
require 'grammar/query_body'
require 'grammar/query_result_filter'

module Grammar
  class Query < Parslet::Parser
    root(:query)

    rule(:query) {
      space? >>
        (query_context >>
         (space >> nicked_query_body).maybe.as(:head) >>
        (space? >> query_tail).maybe.as(:tail) >>
        (space? >> query_result_filter).maybe.as(:filter) >>
        space?).as(:query)
    }

    rule(:query_context) {
      (str("!") >> match('\S').repeat(1)).as(:context)
    }

    rule(:nicked_query_body) {
      QueryBody.new.nick_body
    }

    rule(:query_body) { QueryBody.new }

    rule(:query_tail) {
      str("/") >> space? >> query_body.as(:ratio)
    }

    rule(:query_result_filter) {
      str("?:") >> space? >> QueryResultFilter.new.as(:result_filter)
    }
    rule(:negated) { str("!").as(:negated) }

    rule(:space) { match('\s').repeat(1) }
    rule(:space?) { space.maybe }
  end
end
