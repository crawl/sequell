# -*- coding: utf-8 -*-
require 'spec_helper'
require 'learndb'
require 'fileutils'

describe LearnDB::DB do
  before (:each) {
    FileUtils.mkdir_p('tmp')
    FileUtils.rm_f('tmp/rlearn.db')
  }

  let (:db) { LearnDB::DB.new('tmp/rlearn.db') }

  it 'will add terms' do
    db.entry('cow').add('Mooo!')
    expect(db.entry('cow').size).to eql(1)
    expect(db.entry('cow')[1].text).to eql('Mooo!')
  end

  it 'will be Unicode safe' do
    db.entry("世界中").add("ニュース")
    expect(db.entry('世界中').size).to eql(1)
    expect(db.entry('世界中')[1].text).to eql('ニュース')
  end

  it 'will delete terms' do
    e = db.entry("世界中")
    e.add("ニュース")
    e.add("웹문서, 이미지")
    expect(e.size).to eql(2)
    e.delete(1)
    expect(e.size).to eql(1)
    expect(e[1].text).to eql("웹문서, 이미지")
    e.add("cow")
    expect(e[2].text).to eql("cow")
    expect(e.size).to eql(2)
    e.delete
    expect(e.size).to eql(0)
    expect(e.exists?).to eql(false)
  end

  it 'will update terms' do
    e = db.entry("世界中")
    e.add("ニュース")
    e.add("웹문서, 이미지")
    expect(e.size).to eql(2)
    e[2] = '廣告服務'
    expect(e.size).to eql(2)
    expect(db.entry("世界中")[2].text).to eql('廣告服務')
  end

  it 'will rename terms' do
    db.entry("世界中").add("ニュース")
    db.entry("世界中").rename_to('Адыгэбзэ')
    expect(db.entry('Адыгэбзэ').size).to eql(1)
    expect {
      entry = db.entry('cow')
      entry.add('fief')
      entry.rename_to('Адыгэбзэ')
    }.to raise_error(/Cannot rename cow -> Адыгэбзэ/)
    expect {
      db.entry('miaow').rename_to('rawr')
    }.to raise_error(/miaow doesn't exist/)
  end
end
