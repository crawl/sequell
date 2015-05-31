require 'spec_helper'
require 'sqlhelper'
require 'query/listgame_parser'

describe "!lg parse" do
  def e(tpl)
    Tpl::Template.template(tpl).eval({'nick' => 'cow'})
  end

  def quote(text)
    '"' + text.gsub(/(["\\])/, '\\\\\1') + '"'
  end

  def lg(tpl)
    e("$(lg/parse-cmd #{quote tpl})")
  end

  def fnlg(fn, tpl)
    e("$(#{fn} (lg/parse-cmd #{quote tpl}))")
  end

  it "will parse bare expressions as !lg" do
    expect(lg('* xl>15').context_name).to eql('!lg')
  end

  it "will parse prefixed expressions as prefixed" do
    expect(fnlg('lg/ast-context', '!lg * xl>15')).to eql('!lg')
    expect(fnlg('lg/ast-context', '!lm * xl>15')).to eql('!lm')
  end

  it 'will report nick with ast-nick' do
    expect(fnlg('lg/ast-nick', '!lg * xl>15')).to eql('*')
  end

  it 'will report default nick with ast-default-nick' do
    expect(fnlg('lg/ast-default-nick', '!lg * xl>15')).to eql('cow')
  end

  it "will report head expressions with ast-head" do
    expect(fnlg('lg/ast-head', '!lg * xl>15 / won').to_s).to eql('xl>15')
  end

  it 'will report tail expressions with ast-tail' do
    expect(fnlg('lg/ast-tail', '!lg * xl>15 / won').to_s).to eql('ktyp=winning')
    expect(fnlg('lg/ast-tail', '!lg * xl>15')).to be_nil
  end

  it 'will report the game number with ast-number' do
    expect(fnlg('lg/ast-number', '!lg . xl<10')).to eql(-1)
    expect(fnlg('lg/ast-number', '!lg . xl<10 1')).to eql(0)
    expect(fnlg('lg/ast-number', '!lg . xl<10 0')).to eql(0)
    expect(fnlg('lg/ast-number', '!lg . xl<10 7')).to eql(6)
    expect(fnlg('lg/ast-number', '!lg . xl<10 -5')).to eql(-5)
  end

  it 'will report the o=X order-clause with ast-order' do
    expect(fnlg('lg/ast-order', '!lg * win')).to be_nil
    expect(fnlg('lg/ast-order', '!lg * win s=name o=name').to_s).to eql('o:name')
    expect(fnlg('lg/ast-order', '!lg * win s=name o=.').to_s).to eql('o:.')
    expect(fnlg('lg/ast-order', '!lg * win s=name o=-.').to_s).to eql('o:-.')
  end

  it 'will report the max=X or min=X clause with ast-sort' do
    expect(fnlg('lg/ast-sort', '!lg * win max=xl').to_s).to eql('max=xl')
    expect(fnlg('lg/ast-sort', '!lg * win').to_s).to eql('max=end')
    expect(fnlg('lg/ast-sort', '!lg * win min=dur').to_s).to eql('min=dur')
  end

  it 'will report the s=foo clause with ast-summarise' do
    expect(fnlg('lg/ast-summarise', '!lg * win s=name').to_s).to eql('s=name')
    expect(fnlg('lg/ast-summarise', '!lg * win s=char,-god').to_s).to eql('s=char,-god')
    expect(fnlg('lg/ast-summarise', '!lg * win')).to be_nil
  end

  it 'will report the x=foo,bar clause with ast-extra' do
    expect(fnlg('lg/ast-extra', '!lg * win')).to be_nil
    expect(fnlg('lg/ast-extra', '!lg * win x=xl').to_s).to eql('x=xl')
    expect(fnlg('lg/ast-extra', '!lg * win x=-avg(xl)').to_s).to eql('x=-avg(xl)')
  end

  it 'will report -options with ast-options' do
    expect(fnlg('lg/ast-options', '!lg * win -tv -log').map(&:to_s)).to eql(%w{-tv -log})
    expect(fnlg('lg/ast-options', '!lg * win')).to eql([])
  end

  it 'will report keyed options with ast-keys' do
    expect(fnlg('lg/ast-keys', '!lg * win fmt:"xyz" stub:"moo"')['fmt']).to eql('xyz')
    expect(fnlg('lg/ast-keys', '!lg * win fmt:"xyz" stub:"moo"').to_s).to eql('fmt:"xyz" stub:"moo"')
    expect(fnlg('lg/ast-keys', '!lg * win').to_s).to eql('')
    expect(fnlg('lg/ast-keys', '!lg * win')).not_to be_nil
  end
end
