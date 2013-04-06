require 'spec_helper'
require 'grammar/query_body'

describe Grammar::QueryBody do
  subject { Grammar::QueryBody.new.body_expressions }

  KEYWORD_EXPRESSIONS = [
    "xom nemelex",
    "@78291",
    "!winning",
    "xom|nemelex",
    "!(xom|nemelex|(@78291|!winning))"
  ]

  KEYWORD_EXPRESSIONS.each { |keywords|
    it { should parse(keywords) }
  }
end
