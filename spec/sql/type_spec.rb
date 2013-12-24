ENV['HENZELL_SQL_QUERIES'] = 'y'

require 'spec_helper'
require 'sqlhelper'

describe Sql::Type do
  def t(x)
    Sql::Type.type(x)
  end

  it 'will categorize I and F as numeric' do
    expect(t('I').category).to eq('F')
    expect(t('F').category).to eq('F')
    expect(t('I').numeric?).to be_true
    expect(t('F').numeric?).to be_true
  end
end
