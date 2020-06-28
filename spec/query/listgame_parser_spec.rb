require 'spec_helper'
require 'query/listgame_parser'

describe Query::ListgameParser do
  def self.fragment(fragment_str, &block)
    context(fragment_str) do
      let(:fragment) {
        Query::ListgameParser.fragment(fragment_str)
      }
      instance_eval(&block)
    end
  end

  fragment 't2015a' do
    it 'will translate to the 2015A tournament filter' do
      expect(fragment.to_s).to eql("start>=2015031320 end<2015032920 ((cv=0.16|0.16-a)) explbr=")
    end
  end
end
