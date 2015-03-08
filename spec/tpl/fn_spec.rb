require 'spec_helper'
require 'tpl/template'

describe "Template functions" do
  def e(tpl, scope={})
    Tpl::Template.template_eval(tpl, scope)
  end

  context 'nvl' do
    it 'will return the empty string if no args' do
      expect(e '$(nvl)').to eq('')
    end

    it 'will evaluate form with nvl of empty string if single-arg' do
      expect(e '$(nvl $x)').to eq('')
      expect(e '$(nvl ${x:-foo})').to eq('foo')
      expect(e '$(let (x 3) (nvl $x))').to eq(3)
      expect(e '$(let (x 3) (nvl (set! x 15) $x))').to eq(15)
    end
  end

  context 'with-nvl' do
    it 'will return the nvl value if no other forms' do
      expect(e '$(with-nvl 12)').to eq(12)
    end

    it 'will evaluate forms with the given nvls' do
      expect(e '$(with-nvl cow $x)').to eq('cow')
      expect(e '$(with-nvl cow ${x:-foo})').to eq('cow')
      expect(e '$(let (x 3) (with-nvl cow $x))').to eq(3)
      expect(e '$(let (x 3) (with-nvl cow (set! x moo) $x))').to eq('moo')
    end
  end

  context 'not' do
    it 'will boolean-negate its argument' do
      expect(e('$(not 0)')).to be_truthy
      expect(e('$(not 1)')).to be_falsy
      expect(e('$(not (void))')).to be_truthy
      expect(e('$(not (list))')).to be_truthy
    end
  end

  context 'replace' do
    it 'will replace strings' do
      expect(e('$(replace a x yak)')).to eql('yxk')
      expect(e('$(replace a x yaak)')).to eql('yxxk')
      expect(e('$(replace . x yaak)')).to eql('yaak')
    end
  end

  context 'replace-n' do
    it 'will accept replace counts' do
      expect(e '$(replace-n 1 a yaak)').to eql('yak')
      expect(e '$(replace-n 1 a x yaak)').to eql('yxak')
      expect(e '$(replace-n 0 a x yaak)').to eql('yaak')
      expect(e '$(replace-n -1 a x yaaaaaaak)').to eql('yxxxxxxxk')
    end
  end

  context 'time' do
    it 'will return the current time' do
      now = DateTime.now
      expect(DateTime).to receive(:now).and_return(now)
      expect(e %q{$(time)}).to eql(now)
    end
  end

  context 'ptime' do
    it 'will parse a time' do
      now = DateTime.now
      fmt = '%Y-%m-%d %H:%M:%S'
      s = now.strftime(fmt)
      expect(e "$(ptime '#{s}' '#{fmt}')").to eql(DateTime.strptime(s, fmt))
    end

    it 'will parse IS08601 times by default' do
      now = DateTime.now
      fmt = Tpl::ISO8601_FMT
      s = now.strftime(fmt)
      expect(e "$(ptime '#{s}')").to eql(DateTime.strptime(s, fmt))
    end

  end

  context 'ftime' do
    it 'will format a time' do
      now = DateTime.now
      expect(DateTime).to receive(:now).and_return(now)
      fmt = '%Y-%m-%d %H:%M:%S'
      s = now.strftime(fmt)
      expect(e "$(ftime (time) '#{fmt}')").to eql(s)
    end

    it 'will format a time' do
      now = DateTime.now
      expect(DateTime).to receive(:now).and_return(now)
      fmt = Tpl::ISO8601_FMT
      s = now.strftime(fmt)
      expect(e "$(ftime (time))").to eql(s)
    end
  end

  context 'scope' do
    it 'will return local bindings' do
      expect(e '$(let (x 55) $(elt x (scope)))').to eql(55)
      expect(e '$(let (x 55 y 64) $(elts x y (scope (hash x 32))))')
        .to eql([32, 64])
    end
  end

  context 'binding' do
    it 'will bind forms to the given scope' do
      expect(e '$(binding (hash x 20) $x)').to eql(20)
      expect(e '$(let (y 30) $(binding (hash x 20) $y))').to eql('${y}')
      expect(e '$(let (y 30) $(binding (scope (hash x 20)) $y))').to eql(30)
    end
  end

  context 'eval' do
    it 'will eval templates in the given scope' do
      expect(e %q{$(eval 5)}).to eql('5')
      expect(e %q{$(let (x 3) (eval '$(+ 5 7 $x)'))}).to eql(15)
      expect(e %q{$(let (x 3) (eval `$(+ 5 7 $x)))}).to eql(15)
      expect(e %q{$(let (x 3) (eval `(+ 5 7 $x)))}).to eql(15)
      expect(e %q{$(let (x 3) (eval (quote (+ 5 7 $x))))}).to eql(15)
    end
  end

  context 'exec' do
    it 'will exec subcommands' do
      expect(e %q{$(exec ".echo Hi!")}).to eq('Hi!')
    end
  end

  context 'colour' do
    it 'will produce irc colour codes' do
      expect(e '$(colour red blue)').to eq("\x034,2")
      expect(e '$(colour lightcyan)').to eq("\x0311")
      expect(e '$(colour)').to eq("\x0f")
    end
  end

  context 'coloured' do
    it 'will produce irc colour codes' do
      expect(e '$(coloured red blue Colourful!)').to eq("\x034,2Colourful!\x0f")
      expect(e '$(coloured lightcyan Yay)').to eq("\x0311Yay\x0f")
    end
  end

  context 'sprintf' do
    it 'will return a formatted string' do
      expect(e '$(sprintf "%.2f %5s yak" 3.779 cow)').to eq("3.78   cow yak")
      expect(e '$(sprintf "How now")').to eq("How now")
    end
  end
end
