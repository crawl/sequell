require 'spec_helper'
require 'formatter/duration'

describe Formatter::Duration do
  let (:subject) { Formatter::Duration }
  it 'will format seconds into a duration string' do
    expect(subject.display(2)).to eql('00:00:02')
    expect(subject.display(60)).to eql('00:01:00')
    expect(subject.display(3609)).to eql('01:00:09')
    expect(subject.display(1519187)).to eql('17, 13:59:47')
  end

  it 'will parse a duration string into seconds' do
    expect(subject.parse('00:00:02')).to eql(2)
    expect(subject.parse('00:01:00')).to eql(60)
    expect(subject.parse('01:00:09')).to eql(3609)
    expect(subject.parse('17, 13:59:47')).to eql(1519187)
    expect(subject.parse('1')).to eql(1)
    expect(subject.parse('1, 2')).to eql(86402)
    expect(subject.parse('1, 45:3')).to eql(86403 + 45 * 60)
  end
end
