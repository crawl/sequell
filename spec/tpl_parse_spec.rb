require 'spec_helper'
require 'tpl/template'
require 'tpl/function_defs'
require 'parslet/rig/rspec'

describe Tpl::Template do
  def tpl(text)
    Tpl::Template.template(text)
  end

  def e(text, scope={})
    Tpl::Template.template_eval(text, scope)
  end

  it 'will expand variables' do
    expect(e('$cow', 'cow' => 'moo')).to eq('moo')
  end

  it 'will canonicalize unbound variables' do
    expect(e('$cow')).to eq('${cow}')
  end

  it 'will substitute unbound variables with :-' do
    expect(e('${cow:-Moo!}')).to eq('Moo!')
  end

  it 'will parse function calls' do
    tpl('$(map $x 1,2,3,4)').should be_an_instance_of(Tpl::Funcall)
  end

  it 'will resolve global functions' do
    e('$map').should be_an_instance_of(Tpl::FunctionValue)
    e('${+}').should be_an_instance_of(Tpl::FunctionValue)
  end

  it 'will evaluate functions with apply' do
    e('$(apply ${+} 1,2,3,4,5)').should == 15
  end

  it 'will parse numbers as numbers' do
    tpl('$(list 99)')[0].should == 99
  end

  it 'will evaluate functions' do
    e('$((fn (x) $(* $x 10)) 5)').should == 50
  end

  it 'will parse and eval rest-arg functions' do
    tpl('$(fn (. args))').should be_an_instance_of(Tpl::Function)
    tpl('$(fn (. args))').parameters.should == []
    tpl('$(fn (. args))').rest.should == 'args'
    e('$(= ((fn (. args) $args) 1 2 3) (range 1 3))').should be_true
  end

  it 'will expand boolean false correctly' do
    tpl('${.}').should be_an_instance_of(Tpl::LookupFragment)
    e('${.}', '.' => false).should be_false
  end

  it "will handle function body quoting" do
    tpl('$(fn () "Hi: $_!")').should be_an_instance_of(Tpl::Function)
    tpl('$(fn () "Hi: $_!")').body_forms[0].should be_an_instance_of(Tpl::Fragment)
    tpl('$(fn () "Hi: $_!")').body_forms.first[0].to_s.should == 'Hi: '
    e('$(map (fn (x) "Hi: ${x}!") a|b|c)').should ==
      ['Hi: a!', 'Hi: b!', 'Hi: c!']
  end

  it 'will support recursive named lambdas' do
    name = "fact#{rand(10000)}"
    e("$((fn #{name} (n) $(if (> $n 1) (* $n (#{name} (- $n 1))) 1)) 5)").should == 120
  end

  it 'will parse direct lambda funcalls' do
    tpl('$($(fn (x) $x) $y)').should be_an_instance_of(Tpl::Funcall)
  end

  it 'will interpret (or) expressions' do
    e('$(or (or) (and))').should be_true
    e('$(or (list) 1)').should == 1
  end

  it 'will interpret (and) expressions' do
    e('$(and 1 2 3)').should == 3
  end

  context 'ranges' do
    it 'will create ranges' do
      e('$(split (range 1 4))').should == [1,2,3,4]
      e('$(split (range 1 8 2))').should == [1,3,5,7]
    end
  end

  context 'let' do
    it 'will bind values to names' do
      e('$(let (x 5) $x)').should == 5
    end

    it 'will bind values to names' do
      e('$(let (x "5") $x)').should == "5"
    end

    it 'will evaluate function arguments in the correct scope' do
      e('$(let (x 5) ((fn (y) (let (x 10) $y)) $x))').should == 5
    end

    it 'will permit and eval multiple body forms' do
      e('$(let (x 5) (set! x 10) $x)').should == 10
    end
  end

  context 'hash' do
    it 'will create hashes' do
      e('$(hash)').should == { }
    end

    it 'will evaluate empty hashes as falsy' do
      e('$(or (hash) 22)').should == 22
    end

    it 'will create hashes with the specified keys and values' do
      e('$(hash a b c d)').should == { 'a' => 'b', 'c' => 'd' }
    end

    it 'will parse hash access' do
      tpl('$x[a]').should be_an_instance_of(Tpl::LookupFragment)
    end

    it 'will permit access to hash keys' do
      e('$(let (x (hash a b c d)) $x[a])').should == 'b'
      e('$(let (x (hash a b c d)) $x[c])').should == 'd'
    end

    it 'will permit access to hash keys' do
      e('$(let (x (hash a b c d)) $(elt a $x))').should == 'b'
      e('$(let (x (hash a b c d)) $(elt c $x))').should == 'd'
      e('$(let (x (hash a b c d)) $(elts c a $x))').should == ['d', 'b']
    end

    it 'will support adding keys to hashes' do
      e('$(hash-put e f g h (hash a b c d))').should == {
        'a' => 'b',
        'c' => 'd',
        'e' => 'f',
        'g' => 'h'
      }
    end
  end

  context 'concat' do
    it 'will merge hashes' do
      e('$(concat (hash a b c d) (hash 1 2 3 4))').should == {
        'a' => 'b',
        'c' => 'd',
        1 => 2,
        3 => 4
      }
    end

    it 'will join lists' do
      e('$(concat (list 1 2) (cons) (range 4 6))').should ==
        [1, 2, 4, 5, 6]
    end

    it 'will join strings' do
      e('$(concat "ab" "cd" "" "e")').should == "abcde"
    end
  end

  context 'flatten' do
    it 'will flatten lists to the supplied depth' do
      e('$(flatten (list (list 1 2 (list 3))))').should == [1,2,3]
      e('$(flatten 1 (list (list 1 2 (list 3))))').should == [1,2,[3]]
    end
  end

  context 'sorting' do
    it 'will sort list-like objects' do
      e('$(sort (list 4 3 2 1))').should == [1, 2, 3, 4]
      e('$(sort (fn (a b) $(<=> $b $a)) (list 1 2 3 4))').should ==
        [4, 3, 2, 1]
      e('$(sort (fn (a b) $(<=> $b $a)) (range 1 4))').should ==
        [4, 3, 2, 1]
    end
  end

  context 'reverse' do
    it 'will reverse lists' do
      e('$(reverse (list a b c d))').should == ['d', 'c', 'b', 'a']
    end
    it 'will reverse ranges' do
      e('$(reverse (range 1 4))').should == [4,3,2,1]
    end
    it 'will reverse strings' do
      e('$(reverse abcd)').should == 'dcba'
    end
    it 'will invert hashes' do
      e('$(reverse (hash a b c d))').should == { 'b' => 'a', 'd' => 'c' }
    end
  end

  context 'filter' do
    it 'will filter lists' do
      e('$(filter (fn (z) $(= (mod $z 2) 1)) (list 1 2 3 4 5))').should ==
        [1, 3, 5]

    end
  end
end
