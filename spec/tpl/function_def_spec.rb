require 'spec_helper'
require 'tpl/function_defs'

describe Tpl::FunctionDef do
  subject { Tpl::FunctionDef }

  it 'will find global functions by name' do
    expect(subject.global_function_value('+')).to be_instance_of(Tpl::FunctionValue)
  end
end
