require 'spec_helper'
require 'grammar/query'
require 'parslet/rig/rspec'

describe Grammar::Query do
  subject { Grammar::Query.new }

  QUERIES = [
    '!lg *',
    '!lm *',
    '!lg @78291',
    '!lg *',
    '!lg .',
    '!lg !@Sebi',
    '!lg 4thArraOfDagon',
    '!lg !78291',
    '!lg . 23',
    '!lg * xl>15'
  ]

  QUERIES.each { |query|
    it { should parse(query) }
  }
end
