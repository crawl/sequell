require 'crawl/branch'

module Crawl
  class BranchSet
    def initialize(branches, place_fixups)
      @branches = branches.map { |br|
        Crawl::Branch.new(br)
      }
      @branch_map = Hash[ @branches.map { |br|
          [br.name.downcase, br]
        } ]
      @place_fixups = place_fixups
    end

    def [](name)
      @branch_map[name.downcase]
    end

    def deep?(name)
      branch = self[name]
      branch && branch.deep?
    end

    def branch?(keyword)
      keyword = @place_fixups.fixup(keyword)[0]
      if keyword =~ /^([a-z]+):/i
        self[$1]
      else
        self[keyword]
      end
    end
  end
end
