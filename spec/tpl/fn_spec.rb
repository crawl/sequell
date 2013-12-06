require 'spec_helper'
require 'tpl/template'

describe "Template functions" do
  def e(tpl, scope={})
    Tpl::Template.template_eval(tpl, scope)
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

  context 're-replace' do
    it 'will replace regexps' do
      expect(e '$(re-replace y.*k yuck yak)').to eql('yuck')
      expect(e '$(re-replace "(y)(.*)(k)" (concat $1 (upper $2) $3) yak)').to eql('yAk')
      expect(e %q{$(re-replace '\b([a-z])' (upper $1) "How now brown cow")})
        .to eql('How Now Brown Cow')
      expect(e %q{$(re-replace '\b([a-z])' "How now brown cow")})
        .to eql('How ow rown ow')
    end
  end

  context 're-replace-n' do
    it 'will replace regexps' do
      expect(e '$(re-replace-n 1 y.*k yuck yak)').to eql('yuck')
      expect(e '$(re-replace-n 1 "(y)(.*)(k)" (concat $1 (upper $2) $3) yak)').to eql('yAk')
      expect(e %q{$(re-replace-n 2 '\b([a-z])' (upper $1) "How now brown cow")})
        .to eql('How Now Brown cow')
      expect(e %q{$(re-replace-n 2 '\b([a-z])' "How now brown cow")})
        .to eql('How ow rown cow')
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
    end
  end
end
