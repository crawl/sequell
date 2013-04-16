require 'spec_helper'
require 'tpl/function_defs'

describe Tpl::FunctionDef do
  subject { Tpl::FunctionDef }

  it 'will find global functions by name' do
    subject.global_function_value('+').should be_an_instance_of(Tpl::FunctionValue)
  end
end
