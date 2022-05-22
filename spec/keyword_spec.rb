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

  it "should parse t* as any t" do
    kw = p("t*")
    expect(kw.arguments[0].operator).to eq(:or)
    expect(kw.arguments[0].arguments.size).to eq(Tourney::TOURNEY_DATA['crawl'].keys.size)
  end

  it "should parse t2020a to include file filter" do
    expect(p("t2020a").to_s).to eq("start>='2020-06-12 20:00:00' end<'2020-06-28 20:00:00' ((cv=0.25|0.25-a)) explbr= file!=cwz/soup/trunk/milestones file!=cwz/soup/trunk/logfile")
  end

  it "should parse t2019b without a filter" do
    expect(p("t2019a").to_s).to eq("start>='2019-02-08 20:00:00' end<'2019-02-24 20:00:00' ((cv=0.23|0.23-a)) explbr=")
  end
end
