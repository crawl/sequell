require 'spec_helper'
require 'nick/entry'

describe Nick::Entry do
  describe '.parse' do
    def p(map)
      Nick::Entry.parse(map)
    end

    it 'will parse empty nick mappings' do
      nick = p('cow')
      expect(nick.nick).to eql('cow')
      expect(nick.listgame_conditions).to be_nil
      expect(nick.expansions).to eql(['cow'])
      expect(nick.raw_expansions).to eql([])
      expect(nick.stub?).to be_truthy
      expect(nick.empty?).to be_truthy
    end

    it 'will parse nick mappings with slashes' do
      nick = p('\echo echo')
      expect(nick.nick).to eql('\echo')
      expect(nick.expansions).to eql(['echo'])
    end

    it 'will parse nick mappings with multiple expansions' do
      nick = p('cow foo bar cow')
      expect(nick.nick).to eql('cow')
      expect(nick.listgame_conditions).to be_nil
      expect(nick.expansions).to eql(['foo', 'bar', 'cow'])
      expect(nick.raw_expansions).to eql(nick.expansions)
      expect(nick.stub?).to be_falsy
      expect(nick.empty?).to be_falsy
    end

    it 'will parse nick mappings with expansions and a condition' do
      nick = p('cow foo bar (win)')
      expect(nick.nick).to eql('cow')
      expect(nick.listgame_conditions).to eql('win')
      expect(nick.expansions).to eql(['foo', 'bar'])
      expect(nick.raw_expansions).to eql(nick.expansions)
      expect(nick.stub?).to be_falsy
      expect(nick.empty?).to be_falsy
    end

    it 'will parse nick mappings with expansions and a condition' do
      nick = p('cow  (win god=Xom) bar')
      expect(nick.nick).to eql('cow')
      expect(nick.listgame_conditions).to eql('win god=Xom')
      expect(nick.expansions).to eql(['bar'])
      expect(nick.raw_expansions).to eql(nick.expansions)
      expect(nick.stub?).to be_falsy
      expect(nick.empty?).to be_falsy
    end

    it 'will parse nick mappings with just a condition' do
      nick = p('cow  ( win) ')
      expect(nick.nick).to eql('cow')
      expect(nick.listgame_conditions).to eql('win')
      expect(nick.expansions).to eql([])
      expect(nick.raw_expansions).to eql([])
      expect(nick.stub?).to be_falsy
      expect(nick.empty?).to be_falsy
    end

    it 'will parse nick mappings with an empty condition' do
      nick = p('cow  ( ) ')
      expect(nick.nick).to eql('cow')
      expect(nick.listgame_conditions).to eql('')
      expect(nick.expansions).to eql(['cow'])
      expect(nick.raw_expansions).to eql([])
      expect(nick.stub?).to be_truthy
      expect(nick.empty?).to be_falsy
    end
  end
end
