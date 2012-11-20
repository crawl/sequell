require 'spec_helper'
require 'grammar/query'
require 'parslet/rig/rspec'

describe Grammar::Query do
  subject { Grammar::Query.new }

  QUERIES = [
    '!lg *',
    '!lm *',
    '!lg @78291',
    '!lg !@Sebi',
    '!lg 4thArraOfDagon',
    '!lg !78291',
    '!lg . 23',
    '!lg * xl>15',
    '!lg @78291 xom !winning',
    '!lg * ((tiles || !@hugeterm)) ((ckiller=pandemonium lord || ikiller=cerebov|gloorx vloq|lom lobon|mnoleg|asmodeus|ereshkigal|dispater|geryon ckiller!=player ghost))',
    '!lg * name="78291"',
    '!lg bot xl>11 2 -tv:<T1',
    '!lg bot cv>0.11-a 2 -tv:<T1',
    '!lg * won ((dur<12600 ((start>20110201 || start<20110101)) || turn<40000)) -tv:<T1',

    '!lg * / won',
    '!lg * s=name ?: N>10',
    '!lg * s=name / win ?: %>0.5',
    '!lg * s=name / win ?: d:N > 50 num.N > 5',
    '!lg * s=name x=avg(xl) / win ?: den.avg(xl) > 5 num:N < 3',
    '!lg * win min=turn',
    '!lg * win max=sc',
    '!lg * s=name o=.',
    '!lg * s=name x=max(xl) o=max(xl)',
    '!lg * killer= ktyp=pois'
  ]

  QUERIES.each { |query|
    it { should parse(query) }
  }
end
