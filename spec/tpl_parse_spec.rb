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

  it 'will substitute empty variables with :-' do
    expect(e('${cow:-Moo!}')).to eq('${cow:-Moo!}')
    expect(e('${cow:-Moo!}', 'cow' => '')).to eq('Moo!')
  end

  it 'will substitute empty indexed vars with :-' do
    expect(e('${cow[1]:-Moo!}', {'cow' => ['', '']})).to eq('Moo!')
    expect(e('${cow[1]:-Moo!}', {'cow' => []})).to eq('${cow[1]:-Moo!}')
    expect(e('$(nvl ${cow[1]:-Moo!})', {'cow' => []})).to eq('Moo!')
  end

  it 'will parse function calls' do
    expect(tpl('$(map $x 1,2,3,4)')).to be_instance_of(Tpl::Funcall)
  end

  it 'will resolve global functions' do
    expect(e('$map')).to be_instance_of(Tpl::FunctionValue)
    expect(e('${+}')).to be_instance_of(Tpl::FunctionValue)
  end

  it 'will evaluate functions with apply' do
    expect(e('$(apply ${+} 1,2,3,4,5)')).to eq(15)
  end

  it 'will parse numbers as numbers' do
    expect(tpl('$(list 99)')[0]).to eq(99)
  end

  it 'will evaluate functions' do
    expect(e('$((fn (x) $(* $x 10)) 5)')).to eq(50)
  end

  it 'will parse and eval rest-arg functions' do
    expect(tpl('$(fn (. args))')).to be_instance_of(Tpl::Function)
    expect(tpl('$(fn (. args))').parameters).to eq([])
    expect(tpl('$(fn (. args))').rest).to eq('args')
    expect(e('$(= ((fn (. args) $args) 1 2 3) (range 1 3))')).to be_truthy
  end

  it 'will expand boolean false correctly' do
    expect(tpl('${.}')).to be_instance_of(Tpl::LookupFragment)
    expect(e('${.}', '.' => false)).to be_falsy
  end

  it "will handle function body quoting" do
    expect(tpl('$(fn () "Hi: $_!")')).to be_instance_of(Tpl::Function)
    expect(tpl('$(fn () "Hi: $_!")').body_forms[0]).to be_instance_of(Tpl::Fragment)
    expect(tpl('$(fn () "Hi: $_!")').body_forms.first[0].to_s).to eq('Hi: ')
    expect(e('$(map (fn (x) "Hi: ${x}!") a|b|c)')).to eq(
      ['Hi: a!', 'Hi: b!', 'Hi: c!'])
  end

  it 'will support recursive named lambdas' do
    name = "fact#{rand(10000)}"
    expect(e("$((fn #{name} (n) $(if (> $n 1) (* $n (#{name} (- $n 1))) 1)) 5)")).to eq(120)
  end

  it 'will parse direct lambda funcalls' do
    expect(tpl('$($(fn (x) $x) $y)')).to be_instance_of(Tpl::Funcall)
  end

  it 'will interpret (or) expressions' do
    expect(e('$(or (or) (and))')).to be_truthy
    expect(e('$(or (list) 1)')).to eq(1)
  end

  it 'will interpret (and) expressions' do
    expect(e('$(and 1 2 3)')).to eq(3)
  end

  context 'ranges' do
    it 'will create ranges' do
      expect(e('$(split (range 1 4))')).to eq([1,2,3,4])
      expect(e('$(split (range 1 8 2))')).to eq([1,3,5,7])
    end
  end

  context 'let' do
    it 'will bind values to names' do
      expect(e('$(let (x 5) $x)')).to eq(5)
    end

    it 'will bind values to names' do
      expect(e('$(let (x "5") $x)')).to eq("5")
    end

    it 'will evaluate function arguments in the correct scope' do
      expect(e('$(let (x 5) ((fn (y) (let (x 10) $y)) $x))')).to eq(5)
    end

    it 'will permit and eval multiple body forms' do
      expect(e('$(let (x 5) (set! x 10) $x)')).to eq(10)
    end
  end

  context 'hash' do
    it 'will create hashes' do
      expect(e('$(hash)')).to eq({ })
    end

    it 'will evaluate empty hashes as falsy' do
      expect(e('$(or (hash) 22)')).to eq(22)
    end

    it 'will create hashes with the specified keys and values' do
      expect(e('$(hash a b c d)')).to eq({ 'a' => 'b', 'c' => 'd' })
    end

    it 'will parse hash access' do
      expect(tpl('$x[a]')).to be_instance_of(Tpl::LookupFragment)
    end

    it 'will permit access to hash keys' do
      expect(e('$(let (x (hash a b c d)) $x[a])')).to eq('b')
      expect(e('$(let (x (hash a b c d)) $x[c])')).to eq('d')
    end

    it 'will permit access to hash keys' do
      expect(e('$(let (x (hash a b c d)) $(elt a $x))')).to eq('b')
      expect(e('$(let (x (hash a b c d)) $(elt c $x))')).to eq('d')
      expect(e('$(let (x (hash a b c d)) $(elts c a $x))')).to eq(['d', 'b'])
    end

    it 'will support adding keys to hashes' do
      expect(e('$(hash-put e f g h (hash a b c d))')).to eq({
        'a' => 'b',
        'c' => 'd',
        'e' => 'f',
        'g' => 'h'
      })
    end
  end

  context 'concat' do
    it 'will merge hashes' do
      expect(e('$(concat (hash a b c d) (hash 1 2 3 4))')).to eq({
        'a' => 'b',
        'c' => 'd',
        1 => 2,
        3 => 4
      })
    end

    it 'will join lists' do
      expect(e('$(concat (list 1 2) (cons) (range 4 6))')).to eq(
        [1, 2, 4, 5, 6])
    end

    it 'will join strings' do
      expect(e('$(concat "ab" "cd" "" "e")')).to eq("abcde")
    end
  end

  context 'flatten' do
    it 'will flatten lists to the supplied depth' do
      expect(e('$(flatten (list (list 1 2 (list 3))))')).to eq([1,2,3])
      expect(e('$(flatten 1 (list (list 1 2 (list 3))))')).to eq([1,2,[3]])
    end
  end

  context 'sorting' do
    it 'will sort list-like objects' do
      expect(e('$(sort (list 4 3 2 1))')).to eq([1, 2, 3, 4])
      expect(e('$(sort (fn (a b) $(<=> $b $a)) (list 1 2 3 4))')).to eq(
        [4, 3, 2, 1])
      expect(e('$(sort (fn (a b) $(<=> $b $a)) (range 1 4))')).to eq(
        [4, 3, 2, 1])
    end
  end

  context 'reverse' do
    it 'will reverse lists' do
      expect(e('$(reverse (list a b c d))')).to eq(['d', 'c', 'b', 'a'])
    end
    it 'will reverse ranges' do
      expect(e('$(reverse (range 1 4))')).to eq([4,3,2,1])
    end
    it 'will reverse strings' do
      expect(e('$(reverse abcd)')).to eq('dcba')
    end
    it 'will invert hashes' do
      expect(e('$(reverse (hash a b c d))')).to eq({ 'b' => 'a', 'd' => 'c' })
    end
  end

  context 'filter' do
    it 'will filter lists' do
      expect(e('$(filter (fn (z) $(= (mod $z 2) 1)) (list 1 2 3 4 5))')).to eq(
        [1, 3, 5])
    end
  end
end
