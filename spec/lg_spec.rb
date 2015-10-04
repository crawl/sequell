require 'spec_helper'
require 'query/listgame_parser'
require 'sql/crawl_query'

describe '!lg behavior' do
  def self.query(query_str, &block)
    context(query_str) do
      let(:q) {
        Query::ListgameParser.parse('nick', query_str)
      }
      instance_eval(&block)
    end
  end

  query '!lg * vlong>0.17-a0-1357-g326445f' do
    it 'will search for vlongnum>?' do
      expect(q.to_s).to include('vlongnum>')
    end
  end
end
