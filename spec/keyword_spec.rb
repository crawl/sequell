require 'spec_helper'
require 'grammar/query_body'

describe Grammar::QueryBody do
  subject { Grammar::QueryBody.new.body_expressions }

  KEYWORD_EXPRESSIONS = [
    "xom nemelex",
    "@78291",
    "!winning",
    "xom|nemelex",
    "!(xom|nemelex|(D:1|!winning))"
  ]

  KEYWORD_EXPRESSIONS.each { |keywords|
    it { should parse(keywords) }
  }
end
