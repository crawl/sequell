require 'spec_helper'
require 'query/ast/value'

describe Query::AST::Value do
  context '.single_quote_string' do
    def q(s)
      Query::AST::Value.single_quote_string(s, true)
    end
    
    it 'will quote a string with single quotes' do
      expect(q "cow").to eql("'cow'")
      expect(q "something's").to eql("'something\\\'s'")
    end
  end
end
