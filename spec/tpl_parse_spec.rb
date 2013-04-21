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

  it 'will parse direct lambda funcalls' do
    tpl('$($(fn (x) $x) $y)').should be_an_instance_of(Tpl::Funcall)
  end

  it 'will interpret (or) expressions' do
    tpl_eval('$(or (or) (and))').should be_true
    tpl_eval('$(or (list) 1)').should == 1
  end

  it 'will interpret (and) expressions' do
    tpl_eval('$(and 1 2 3)').should == 3
  end

  context 'ranges' do
    it 'will create ranges' do
      tpl_eval('$(split (range 1 4))').should == [1,2,3,4]
      tpl_eval('$(split (range 1 8 2))').should == [1,3,5,7]
    end
  end

  context 'hash' do
    it 'will create hashes' do
      tpl_eval('$(hash)').should == { }
    end

    it 'will evaluate empty hashes as falsy' do
      tpl_eval('$(or (hash) 22)').should == 22
    end

    it 'will create hashes with the specified keys and values' do
      tpl_eval('$(hash a b c d)').should == { 'a' => 'b', 'c' => 'd' }
    end

    it 'will parse hash access' do
      tpl('$x[a]').should be_an_instance_of(Tpl::LookupFragment)
    end

    it 'will permit access to hash keys' do
      tpl_eval('$(let (x (hash a b c d)) $x[a])').should == 'b'
      tpl_eval('$(let (x (hash a b c d)) $x[c])').should == 'd'
    end

    it 'will permit access to hash keys' do
      tpl_eval('$(let (x (hash a b c d)) $(elt a $x))').should == 'b'
      tpl_eval('$(let (x (hash a b c d)) $(elt c $x))').should == 'd'
      tpl_eval('$(let (x (hash a b c d)) $(elts c a $x))').should == ['d', 'b']
    end

    it 'will support adding keys to hashes' do
      tpl_eval('$(hash-put e f g h (hash a b c d))').should == {
        'a' => 'b',
        'c' => 'd',
        'e' => 'f',
        'g' => 'h'
      }
    end
  end

  context 'concat' do
    it 'will merge hashes' do
      tpl_eval('$(concat (hash a b c d) (hash 1 2 3 4))').should == {
        'a' => 'b',
        'c' => 'd',
        1 => 2,
        3 => 4
      }
    end

    it 'will join lists' do
      tpl_eval('$(concat (list 1 2) (cons) (range 4 6))').should ==
        [1, 2, 4, 5, 6]
    end

    it 'will join strings' do
      tpl_eval('$(concat "ab" "cd" "" "e")').should == "abcde"
    end
  end

  context 'flatten' do
    it 'will flatten lists to the supplied depth' do
      tpl_eval('$(flatten (list (list 1 2 (list 3))))').should == [1,2,3]
      tpl_eval('$(flatten 1 (list (list 1 2 (list 3))))').should == [1,2,[3]]
    end
  end

  context 'sorting' do
    it 'will sort list-like objects' do
      tpl_eval('$(sort (list 4 3 2 1))').should == [1, 2, 3, 4]
      tpl_eval('$(sort (fn (a b) $(<=> $b $a)) (list 1 2 3 4))').should ==
        [4, 3, 2, 1]
      tpl_eval('$(sort (fn (a b) $(<=> $b $a)) (range 1 4))').should ==
        [4, 3, 2, 1]
    end
  end

  context 'reverse' do
    it 'will reverse lists' do
      tpl_eval('$(reverse (list a b c d))').should == ['d', 'c', 'b', 'a']
    end
    it 'will reverse ranges' do
      tpl_eval('$(reverse (range 1 4))').should == [4,3,2,1]
    end
    it 'will reverse strings' do
      tpl_eval('$(reverse abcd)').should == 'dcba'
    end
    it 'will invert hashes' do
      tpl_eval('$(reverse (hash a b c d))').should == { 'b' => 'a', 'd' => 'c' }
    end
  end

  context 'filter' do
    it 'will filter lists' do
      tpl_eval('$(filter (fn (z) $(= (mod $z 2) 1)) (list 1 2 3 4 5))').should ==
        [1, 3, 5]

    end
  end
end
