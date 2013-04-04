require 'spec_helper'
require 'grammar/query'
require 'parslet/rig/rspec'

describe Grammar::Query do
  subject { Grammar::Query.new }

  QUERIES = [
    '!lg *',
    '!lg xl>15',
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
    '!lg * killer= ktyp=pois',
    '!lg elliptic win -ttyrec',
    '!lg * win s=sc',
    '!lg * s=length(name)',
    '!lg * x=max(length(name))',
    '!lg * char=hobe / won',
    '!lg * cv>=0.10 sc>0 s=log(sc),cv o=-. -graph:area',
    '!lg * day(end)=20121029 s=day(end) x=sum(sc) / tiles ',
    '!lg * s=day(end) x=sum(sc) / tiles -graph',
    '!lg * s=trunc99(sc)',
    '!lg * won start>=20120101 s=day(end),tiles -graph',
    '!lg * 0.11-a tiles xl>10 s=god% -graph',
    '!lg * won cv>=0.5 s=char / end>=20101020 ?:%=1',
    '!lg * ac>${ev+sh}',
    '!lg * x=log(log(sc))',
    '!lg * kmap&map=foo',
    '!lg * kmap|map=foo',
    '!lg * ${ac > (ev + sh) * 2}',
    '!lg * ${log(ac) > 5}',
    '!lg * x=${log(log(sc))}',
    '!lg * !((killer=tentacled monstrosity))',
    '!lg * $ ac > ev + sh',
    '!lg * $ ac + ev + sh > 15',
    '!lg * $ ac > ev + sh $',
    '!lg * $ ac > ev + sh $ / win ?: N = 0',
    '!lg * $ 2 + 3 * 4 / 5 > 0',
    '!lg * ktyp= killer=foo'
  ]

  QUERIES.each { |query|
    it { should parse(query) }
  }
end
