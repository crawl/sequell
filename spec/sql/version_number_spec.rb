require 'spec_helper'
require 'sql/version_number'

describe Sql::VersionNumber do
  def vnumber(ver)
    Sql::VersionNumber.version_numberize(ver)
  end

  it 'will convert version strings to numbers' do
    cases = [
      ["0.1.7", 100799000000],
      ["0.8.0-a0", 800001000000],
      ["0.8.0-rc1", 800018010000],
      ["0.9.0", 900099000000],
      ["0.9", 900099000000],
      ["0.10.4", 1000499000000]
    ]
    cases.each { |ver, vnum|
      expect(vnumber(ver)).to eql(vnum)
    }
  end

  it 'will order versions correctly' do
    cases = [
      ["0.15.0-9-g1a96a59", "0.15.0-34-g666c3a1", "0.15.1"],
      ["0.15.0", "0.15.0-9-g1a96a59", "0.15.0-34-g666c3a1"]
    ]
    cases.each { |ord|
      prev = 0
      for ver in ord
        vnum = vnumber(ver)
        expect(vnum).to be > prev
        prev = vnum
      end
    }
  end
end
