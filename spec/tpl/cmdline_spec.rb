require 'spec_helper'
require 'grammar/command_line'

describe 'Command-line parser' do
  def c(text)
    Grammar::CommandLineBuilder.build(text)
  end

  let(:args) {
    c(%{how now "brown cow" 'why do you frown' "beneath the \\"bough\\""})
  }

  it 'will parse quoted strings' do
    expect(args).to eql(["how", "now", "brown cow", "why do you frown", 'beneath the "bough"'])
  end
end
