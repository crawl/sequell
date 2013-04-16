require 'spec_helper'
require 'tpl/template'
require 'tpl/function_defs'
require 'parslet/rig/rspec'

describe Tpl::Template do
  def tpl(text)
    Tpl::Template.template(text)
  end

  def tpl_eval(text, scope={})
    Tpl::Template.template_eval(text, scope)
  end

  it 'will parse function calls' do
    tpl('$(map $x 1,2,3,4)').should be_an_instance_of(Tpl::Funcall)
  end

  it 'will resolve global functions' do
    tpl_eval('$map').should be_an_instance_of(Tpl::FunctionValue)
    tpl_eval('${+}').should be_an_instance_of(Tpl::FunctionValue)
  end

  it 'will evaluate functions with apply' do
    tpl_eval('$(apply ${+} 1,2,3,4,5)').should == 15
  end

  it 'will parse numbers as numbers' do
    tpl('$(list 99)')[0].should == 99
  end

  it 'will evaluate functions' do
    tpl_eval('$((fn (x) $(* $x 10)) 5)').should == 50
  end

  it 'will parse and eval anonymous undeclared-arg functions' do
    tpl_eval('$((fn $(* $_ 10)) 2)').should == 20
  end

  it 'will parse and eval rest-arg functions' do
    tpl('$(fn (. args))').should be_an_instance_of(Tpl::Function)
    tpl('$(fn (. args))').parameters.should == []
    tpl('$(fn (. args))').rest.should == 'args'
    tpl_eval('$(= ((fn (. args) $args) 1 2 3) (range 1 3))').should be_true
  end

  it 'will expand boolean false correctly' do
    tpl('${.}').should be_an_instance_of(Tpl::LookupFragment)
    tpl_eval('${.}', '.' => false).should be_false
  end

  it "will handle function body quoting" do
    tpl('$(fn Hi: $_!)').should be_an_instance_of(Tpl::Function)
    tpl('$(fn Hi: $_!)').body.should be_an_instance_of(Tpl::Fragment)
    tpl('$(fn Hi: $_!)').body[0].to_s.should == 'Hi: '
    tpl_eval('$(map (fn Hi: $_!) a|b|c)').should ==
      ['Hi: a!', 'Hi: b!', 'Hi: c!']
  end

  it 'will support recursive named lambdas' do
    name = "fact#{rand(10000)}"
    tpl_eval("$((fn #{name} (n) $(if (> $n 1) (* $n (#{name} (- $n 1))) 1)) 5)").should == 120
  end
end
