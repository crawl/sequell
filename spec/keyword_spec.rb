require 'spec_helper'
require 'grammar/query_body'
require 'query/listgame_parser'

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

  def p(fragment)
    Query::ListgameParser.fragment(fragment)
  end

  it "should parse a standalone KE as Tengu" do
    kw = p("Ke")
    expect(kw.to_s).to eq('crace=Tengu')
  end

  it "should parse a standalone HE as High Elf (because Healers are dead)" do
    kw = p("HE")
    expect(kw.to_s).to eq("crace='High Elf'")
  end
end
