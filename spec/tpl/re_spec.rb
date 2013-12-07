require 'spec_helper'
require 'tpl/template'

describe 'RE' do
  def e(tpl)
    Tpl::Template.template(tpl).eval({'nick' => 'cow'})
  end

  context 're-find' do
    context 'with no start index' do
      it 'will return nil if not matched' do
        expect(e('$(re-find mo+ mack)')).to be_nil
      end

      it 'will return a match object if matched' do
        expect(e('$(re-find mo+ mooo)')).to be_a(RE2::MatchData)
      end

      it 'will provide the start and end indexes of matches and groups' do
        expect(e('$(match-begin (re-find mo+ "Cows go mooo!"))')).to eq(8)
        expect(e('$(match-end (re-find mo+ "Cows go mooo!"))')).to eq(12)
        expect(e('$(match-begin (re-find "m(o+)" "Cows go mooo!") 1)')).to eq(9)
        expect(e('$(match-end (re-find "m(o)+" "Cows go mooo!") 1)')).to eq(12)
        expect(e('$(match-groups (re-find "m(o+)" "Cows go mooo!"))'))
          .to eq(['mooo', 'ooo'])
        expect(e('$(match-n (re-find "m(o+)" "Cows go mooo!") 0)'))
          .to eq('mooo')
        expect(e('$(match-n (re-find "m(o+)" "Cows go mooo!") 1)'))
          .to eq('ooo')
        expect(e('$(match-n (re-find "m(?P<yak>o+)" "Cows go mooo!") yak)'))
          .to eq('ooo')
      end
    end

    context 'with a start index' do
      it 'will begin matching at that index' do
        expect(e(%q{$(str (re-find '(?i)m\w+' "Mighty malefic mackerel"))}))
          .to eq('Mighty')
        expect(e(%q{$(str (re-find '(?i)m\w+' "Mighty malefic mackerel" 2))}))
          .to eq('malefic')
      end
    end
  end


  context 're-replace' do
    it 'will replace regexps' do
      expect(e '$(re-replace y.*k yuck yak)').to eql('yuck')
      expect(e '$(re-replace "(y)(.*)(k)" (quote (concat $1 (upper $2) $3)) yak)').to eql('yAk')
      expect(e '$(re-replace "(y)(.*)(k)" \'$(concat $1 (upper $2) $3)\' yak)').to eql('yAk')
      expect(e %q{$(re-replace '\b([a-z])' (quote (upper $1)) "How now brown cow")})
        .to eql('How Now Brown Cow')
      expect(e %q{$(re-replace '\b([a-z])' "How now brown cow")})
        .to eql('How ow rown ow')
    end
  end

  context 're-replace-n' do
    it 'will replace regexps' do
      expect(e %q{$(re-replace-n 2 '\b([a-z])(\w+)' `"$(upper $1)$2 $nick" "How now brown cow")})
        .to eq('How Now cow Brown cow cow')

      expect(e '$(re-replace-n 1 y.*k yuck yak)').to eql('yuck')
      expect(e '$(re-replace-n 1 "(y)(.*)(k)" (quote (concat $1 (upper $2) $3)) yak)').to eql('yAk')

      expect(e '$(re-replace-n 1 "(y)(.*)(k)" (fn () (concat $1 (upper $2) $3)) yak)').to eql('yAk')

      expect(e '$(re-replace-n 1 "(y)(.*)(k)" (fn (m) "${m[1]}$(upper $m[2])${m[3]}") yak)').to eql('yAk')
      expect(e '$(re-replace "(y)(.*)(k)" (fn () "$1$(upper $2)$3") yak)')
        .to eql('yAk')

      expect(e %q{$(re-replace-n 2 '\b([a-z])' "How now brown cow")})
        .to eql('How ow rown cow')
    end
  end
end
