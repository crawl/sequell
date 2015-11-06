require 'spec_helper'
require 'grammar/query_body'
require 'query/listgame_parser'
require 'query/ast/ast_fixup'
require 'tourney'

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
    Query::AST::ASTFixup::result(Query::ListgameParser.fragment(fragment), true)
  end

  it "should parse a standalone KE as Tengu" do
    kw = p("Ke")
    expect(kw.to_s).to eq('crace=Tengu')
  end

  it "should parse a standalone HE as High Elf (because Healers are dead)" do
    kw = p("HE")
    expect(kw.to_s).to eq("crace='High Elf'")
  end

  it "should parse t* as any t" do
    kw = p("t*")
    expect(kw.arguments[0].operator).to eq(:or)
    expect(kw.arguments[0].arguments.size).to eq(Tourney::TOURNEY_DATA['crawl'].keys.size)
  end
end
