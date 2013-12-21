# -*- coding: utf-8 -*-
require 'spec_helper'
require 'fileutils'
require 'learndb'
require 'tpl/template'

describe 'LearnDB functions' do
  def e(tpl)
    Tpl::Template.template(tpl).eval('nick' => 'cow')
  end

  let (:db) { LearnDB::DB.new('tmp/rlearn.db') }

  before(:each) {
    FileUtils.mkdir_p('tmp')
    FileUtils.rm_f('tmp/rlearn.db')
    allow(LearnDB::DB).to receive(:default).and_return(db)
  }

  context 'ldb-at, ldb-defs' do
    before(:each) {
      db.entry('世界').add('めのツ')
      db.entry('世界').add('Moo?')
    }

    it 'will query definitions' do
      expect(e(%{$(ldb-at 世界)}).text).to eql('めのツ')
      expect(e(%{$(ldb-size 世界)})).to eql(2)
      expect(e(%{$(ldb-at 世界 1)}).text).to eql('めのツ')
      expect(e(%{$(ldb-at 世界 2)}).text).to eql('Moo?')
      expect(e(%{$(ldb-at 世界 0)}).text).to eql('めのツ')
      expect(e(%{$(ldb-at 世界 -1)}).text).to eql('Moo?')
      expect(e(%{$(ldb-at 世界 -2)}).text).to eql('めのツ')
      expect(e(%{$(ldb-defs 世界)})).to eql(['めのツ', 'Moo?'])
    end

    it 'will support entry lookups' do
      expect(e(%{$(ldbent-term (ldb-at 世界 2))})).to eql('世界')
      expect(e(%{$(ldbent-index (ldb-at 世界 2))})).to eql(2)
      expect(e(%{$(ldbent-term-size (ldb-at 世界 2))})).to eql(2)
      expect(e(%{$(ldbent-text (ldb-at 世界 2))})).to eql('Moo?')
    end

    it 'will fold nils through ldbent-*' do
      expect(e(%{$(ldbent-term (ldb-at 世界 20))})).to eql('')
      expect(e(%{$(ldbent-index (ldb-at 世界 20))})).to eql(0)
      expect(e(%{$(ldbent-term-size (ldb-at 世界 20))})).to eql(0)
      expect(e(%{$(ldbent-text (ldb-at 世界 20))})).to eql('')
    end
  end

  context 'ldb-rm!' do
    it 'will delete terms and definitions' do
      db.entry('世界').add('めのツ')
      expect(e(%{$(ldb-at 世界)}).text).to eql('めのツ')
      db.entry('世界').add('Moo?')
      expect(e(%{$(ldb-size 世界)})).to eql(2)
      e(%{$(ldb-rm! 世界 *)})
      expect(e(%{$(ldb-size 世界)})).to eql(0)

      db.entry('世界').add('めのツ')
      expect(e(%{$(ldb-at 世界)}).text).to eql('めのツ')
      db.entry('世界').add('Moo?')
      expect(e(%{$(ldb-size 世界)})).to eql(2)
      e(%{$(ldb-rm! 世界 1)})
      expect(e(%{$(ldb-size 世界)})).to eql(1)
      expect(e(%{$(ldb-at 世界 1)}).text).to eql('Moo?')
    end
  end

  context 'ldb-set!' do
    it 'will modify definitions' do
      db.entry('世界').add('めのツ')
      db.entry('世界').add('Moo?')
      e(%{$(ldb-set! 世界 2 乗換案内)})
      expect(e(%{$(ldb-at 世界 2)}).text).to eql('乗換案内')
    end

    it 'will do nothing if asked to overwrite a nonexistent definition' do
      e(%{$(ldb-set! panda 2 乗換案内)})
      expect(LearnDB::DB.default.term_exists?('panda')).to eql(false)
    end
  end

  context 'ldb-add' do
    before(:each) {
      db.entry('世界').add('めのツ')
      db.entry('世界').add('Moo?')
    }

    it 'will append definitions with no index' do
      e(%{$(ldb-add 世界 乗換案内)})
      expect(e('$(ldb-size 世界)')).to eql(3)
      expect(e(%{$(ldb-at 世界 3)}).text).to eql('乗換案内')
    end

    it 'will insert definitions with an index' do
      e(%{$(ldb-add 世界 2 Cow)})
      expect(e('$(ldb-size 世界)')).to eql(3)
      expect(e(%{$(ldb-at 世界 3)}).text).to eql('Moo?')
      expect(e(%{$(ldb-at 世界 2)}).text).to eql('Cow')

      e(%{$(ldb-add 世界 1 First!)})
      expect(e('$(ldb-size 世界)')).to eql(4)
      expect(e(%{$(ldb-at 世界)}).text).to eql('First!')

      e(%{$(ldb-add 世界 -1 Last!)})
      expect(e(%{$(ldb-at 世界 5)}).text).to eql('Last!')
    end
  end

  context 'ldb full queries' do
    before(:each) {
      db.entry('世界').add('めのツ')
      db.entry('世界').add('Moo?')
      db.entry('世界').add('see {世界[3]}')
      db.entry('世界').add('see {.echo Heyy ${nick}!}')
      db.entry('世界').add('do {.echo Hi there, ${nick}!}')
      db.entry('世界').add('How now, ${nick}!')
      db.entry('moo').add('see {世界}')
      db.entry('pow').add('Powpow')
      db.entry('pow').add('see {世界[2]}')
      db.entry('link').add('see {other}')
      db.entry('other').add('see {世界}')
    }

    it 'will lookup similar terms iwth ldb-similar-terms' do
      expect(e('$(ldb-similar-terms links)')).to eq(['link'])
      expect(e('$(ldb-similar-terms linkses 3)')).to eq(['link'])
    end

    it 'will search terms with ldb-search-terms' do
      expect(e('$(ldb-search-terms po.)')).to eq(['pow'])
    end

    it 'wil search entries with ldb-search-entries' do
      expect(e('$(str (ldb-search-entries "How now"))')).to eq('世界[6/6]: How now, ${nick}!')
    end

    it 'will follow redirects' do
      expect(e('$(ldb moo)').to_s).to eql('世界[1/6]: めのツ')
      expect(e('$(ldb-lookup pow[2])').to_s).to eql('世界[2/6]: Moo?')
      expect(e('$(ldb-lookup powz[2])').to_s).to eql('powz ~ pow ~ 世界[2/6]: Moo?')
      expect(e('$(ldb-lookup 世界[$])').to_s).to eql('世界[6/6]: How now, cow!')
    end

    it 'will break infinite redirect loops' do
      expect(e('$(ldb 世界 3)').to_s).to eql('世界[3/6]: see {世界[3]}')
    end

    it 'will redirect through link-only entries' do
      expect(e('$(ldb link -1)').to_s).to eql("世界[6/6]: How now, cow!")
      expect(e('$(ldb link 4)').to_s).to eql("Heyy cow!")
      expect(e('$(ldb link -2)').to_s).to eql("Hi there, cow!")
    end
  end
end
